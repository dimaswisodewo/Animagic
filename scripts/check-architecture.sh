#!/usr/bin/env bash
#
# Validate AniMagic's source ownership boundaries.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/Animagic"
DOMAIN_DIR="$SOURCE_DIR/Domain"
PLATFORM_DIR="$SOURCE_DIR/Platform"
DESIGN_SYSTEM_DIR="$SOURCE_DIR/DesignSystem"
failed=0

report_matches() {
    local message="$1"
    shift
    local matches
    matches="$("$@" || true)"
    if [[ -n "$matches" ]]; then
        echo "Architecture error: $message" >&2
        echo "$matches" >&2
        failed=1
    fi
}

report_matches \
    "Domain imports a prohibited implementation or presentation framework." \
    rg -n '^[[:space:]]*import[[:space:]]+(SwiftUI|SwiftData|Vision|CoreML|RealityKit|ARKit|AVFoundation|Photos)([[:space:]]|$)' \
    "$DOMAIN_DIR" --glob '*.swift'

report_matches \
    "Platform references a feature-owned module path or imports a feature module." \
    rg -n '(Animagic/Features|^[[:space:]]*import[[:space:]]+.*Feature)' \
    "$PLATFORM_DIR" --glob '*.swift'

report_matches \
    "DesignSystem contains feature-specific UI." \
    rg -n '(ARPlacement|Backpack|DrawingCanvas|DrawingDetail|VirtualRoom|CutoutLibrary)' \
    "$DESIGN_SYSTEM_DIR" --glob '*.swift'

while IFS= read -r source; do
    if ! sed -n '1,9p' "$source" | rg -q 'Created by .+ on [0-9]{2}/[0-9]{2}/[0-9]{2}\.'; then
        echo "Architecture error: missing or malformed Xcode author header: ${source#"$ROOT_DIR/"}" >&2
        failed=1
    fi
done < <(find "$SOURCE_DIR" -name '*.swift' -type f | sort)

echo "Files above 400 lines (responsibility review required):"
while IFS= read -r source; do
    lines="$(wc -l < "$source" | tr -d ' ')"
    if (( lines > 400 )); then
        printf '  %5d  %s\n' "$lines" "${source#"$ROOT_DIR/"}"
    fi
done < <(find "$SOURCE_DIR" -name '*.swift' -type f | sort)

if (( failed != 0 )); then
    exit 1
fi

echo "Architecture checks passed."

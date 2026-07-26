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
LARGE_FILE_EXCEPTIONS="$ROOT_DIR/docs/architecture-large-file-exceptions.txt"
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

if [[ ! -f "$LARGE_FILE_EXCEPTIONS" ]]; then
    echo "Architecture error: missing large-file exception manifest." >&2
    failed=1
fi

echo "Reviewed files above 400 lines:"
while IFS= read -r source; do
    lines="$(wc -l < "$source" | tr -d ' ')"
    if (( lines > 400 )); then
        relative_source="${source#"$ROOT_DIR/"}"
        if [[ -f "$LARGE_FILE_EXCEPTIONS" ]] && \
            rg -Fxq "$relative_source" "$LARGE_FILE_EXCEPTIONS"; then
            printf '  %5d  %s\n' "$lines" "$relative_source"
        else
            echo "Architecture error: $relative_source has $lines lines and is not reviewed." >&2
            echo "Split it or document the exception in docs/ARCHITECTURE.md and $LARGE_FILE_EXCEPTIONS." >&2
            failed=1
        fi
    fi
done < <(find "$SOURCE_DIR" -name '*.swift' -type f | sort)

if [[ -f "$LARGE_FILE_EXCEPTIONS" ]]; then
    while IFS= read -r relative_source; do
        [[ -z "$relative_source" || "$relative_source" == \#* ]] && continue
        if [[ ! -f "$ROOT_DIR/$relative_source" ]]; then
            echo "Architecture error: stale large-file exception: $relative_source" >&2
            failed=1
        elif (( $(wc -l < "$ROOT_DIR/$relative_source") <= 400 )); then
            echo "Architecture error: unnecessary large-file exception: $relative_source" >&2
            failed=1
        fi
    done < "$LARGE_FILE_EXCEPTIONS"
fi

if (( failed != 0 )); then
    exit 1
fi

echo "Architecture checks passed."

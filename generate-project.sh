#!/usr/bin/env bash
# Generate AniMagic.xcodeproj from the checked-in XcodeGen specification.
#
# Usage:
#   ./generate-project.sh                         Regenerate the committed Xcode project.
#   ./generate-project.sh --check                 Verify the committed project is current.
#   ./generate-project.sh --spec path/project.yml Use an alternate XcodeGen specification.
#   ./generate-project.sh --help                  Show this help text.
#
# The script exits nonzero when a dependency or input is missing, generation
# fails, or --check detects that the committed project is stale.
set -euo pipefail

# Resolve the repository root so the command works from any directory. This
# script lives at the repository root (not in a Scripts subdirectory).
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="AniMagic"
PROJECT_PATH="$ROOT_DIR/$PROJECT_NAME.xcodeproj"
DEFAULT_SPEC="${XCODEGEN_SPEC:-project.yml}"

MODE="generate"
SPEC_ARGUMENT="$DEFAULT_SPEC"
TEMP_DIR=""

usage() {
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
}

fail() {
    echo "Error: $*" >&2
    exit 1
}

cleanup() {
    # Check mode must not leave generated projects or temporary files behind.
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Parse a deliberately small interface so unsupported arguments fail clearly.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)
            MODE="check"
            shift
            ;;
        --spec)
            [[ $# -ge 2 ]] || fail "--spec requires a file path."
            SPEC_ARGUMENT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            fail "Unknown argument: $1"
            ;;
    esac
done

# Relative specification paths are interpreted from the repository root.
if [[ "$SPEC_ARGUMENT" = /* ]]; then
    SPEC_FILE="$SPEC_ARGUMENT"
else
    SPEC_FILE="$ROOT_DIR/$SPEC_ARGUMENT"
fi

[[ -f "$SPEC_FILE" ]] || fail "XcodeGen spec was not found: $SPEC_FILE"

# A provisioning profile is CMS data embedded by Xcode during signing. It must
# never be passed to codesign as a nested code object.
if grep -q 'embedded\.mobileprovision' "$SPEC_FILE"; then
    fail "The XcodeGen spec attempts to codesign embedded.mobileprovision; remove that command."
fi

# Installing tools is intentionally left to the developer or CI bootstrap step.
if ! command -v xcodegen >/dev/null 2>&1; then
    echo "XcodeGen is required but was not found." >&2
    echo "Install it with: brew install xcodegen" >&2
    echo "Project: https://github.com/yonaskolb/XcodeGen" >&2
    exit 1
fi

generate_project() {
    local output_directory="$1"
    shift

    # project-root keeps source paths anchored to the repository when output is temporary.
    xcodegen generate \
        --spec "$SPEC_FILE" \
        --project-root "$ROOT_DIR" \
        --project "$output_directory" \
        "$@"
}

if [[ "$MODE" == "check" ]]; then
    [[ -f "$PROJECT_PATH/project.pbxproj" ]] || \
        fail "$PROJECT_NAME.xcodeproj is missing; run ./Scripts/generate-project.sh first."

    # Recreate the repository's relative layout outside the repository. XcodeGen
    # embeds path-dependent project entries, so a plain temporary output directory
    # would produce a false difference even when the specification is current.
    TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/AniMagic-xcodegen.XXXXXX")"
    SHADOW_SPEC="$TEMP_DIR/$(basename "$SPEC_FILE")"
    cp "$SPEC_FILE" "$SHADOW_SPEC"
    ln -s "$ROOT_DIR/Animagic" "$TEMP_DIR/Animagic"
    xcodegen generate \
        --spec "$SHADOW_SPEC" \
        --project-root "$TEMP_DIR" \
        --project "$TEMP_DIR" \
        --quiet
    GENERATED_PBXPROJ="$TEMP_DIR/$PROJECT_NAME.xcodeproj/project.pbxproj"
    [[ -f "$GENERATED_PBXPROJ" ]] || \
        fail "XcodeGen did not create the expected project in $TEMP_DIR."

    if ! cmp -s "$GENERATED_PBXPROJ" "$PROJECT_PATH/project.pbxproj"; then
        echo "The committed $PROJECT_NAME.xcodeproj is out of date." >&2
        echo "Run ./Scripts/generate-project.sh and commit the regenerated project." >&2
        exit 1
    fi

    echo "$PROJECT_NAME.xcodeproj is consistent with $(basename "$SPEC_FILE")."
    exit 0
fi

echo "XcodeGen: $(xcodegen --version)"
echo "Spec: $SPEC_FILE"
echo "Generating $PROJECT_PATH..."
generate_project "$ROOT_DIR"

[[ -f "$PROJECT_PATH/project.pbxproj" ]] || \
    fail "XcodeGen completed without creating $PROJECT_PATH/project.pbxproj."

echo "Generated $PROJECT_NAME.xcodeproj successfully."

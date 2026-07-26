#!/usr/bin/env bash
#
# Run deterministic repository structure validation.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/check-architecture.sh"
"$ROOT_DIR/generate-project.sh" --check
git -C "$ROOT_DIR" diff --check

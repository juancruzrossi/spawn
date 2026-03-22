#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
INSTALL_HELPER="$SCRIPT_DIR/scripts/install-runtime.js"

if ! command -v node >/dev/null 2>&1; then
  echo "Could not read version from package.json (is Node.js installed?)"
  exit 1
fi

VERSION=$(node "$INSTALL_HELPER" --package-dir "$SCRIPT_DIR" --strict-rc --print version)
printf '✅ spawn installed successfully (v%s)\n' "$VERSION"

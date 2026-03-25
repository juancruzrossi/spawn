#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

if ! command -v npm >/dev/null 2>&1; then
  echo "npm not found. Install Node.js 18+ first."
  exit 1
fi

npm install -g "$SCRIPT_DIR"

VERSION=$(node -p "require(process.argv[1]).version" "$SCRIPT_DIR/package.json")
printf '✅ spawn installed successfully (v%s)\n' "$VERSION"
echo 'Open a new shell to use `spawn cd` as well.'

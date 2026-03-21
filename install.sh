#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
INSTALL_DIR="$HOME/.spawn"
INSTALL_PATH="$INSTALL_DIR/spawn.sh"
VERSION_PATH="$INSTALL_DIR/VERSION"
LIB_DIR="$INSTALL_DIR/lib"
TMP_DIR=""

cleanup() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf -- "$TMP_DIR"
  fi
}

trap cleanup EXIT INT TERM HUP

if [ ! -f "$SCRIPT_DIR/spawn.sh" ]; then
  echo "spawn.sh not found next to install.sh"
  exit 1
fi

if [ ! -f "$SCRIPT_DIR/package.json" ]; then
  echo "package.json not found next to install.sh"
  exit 1
fi

if [ ! -d "$SCRIPT_DIR/lib" ]; then
  echo "lib directory not found next to install.sh"
  exit 1
fi

VERSION=$(node -e "process.stdout.write(require('./package.json').version)" 2>/dev/null) || {
  echo "Could not read version from package.json (is Node.js installed?)"
  exit 1
}

mkdir -p "$INSTALL_DIR"
TMP_DIR=$(mktemp -d)

cp "$SCRIPT_DIR/spawn.sh" "$TMP_DIR/spawn.sh"
printf '%s\n' "$VERSION" > "$TMP_DIR/VERSION"
cp -R "$SCRIPT_DIR/lib" "$TMP_DIR/lib"

mv "$TMP_DIR/spawn.sh" "$INSTALL_PATH"
mv "$TMP_DIR/VERSION" "$VERSION_PATH"
rm -rf -- "$LIB_DIR"
mv "$TMP_DIR/lib" "$LIB_DIR"
TMP_DIR=""

case "$SHELL" in
  */zsh) RC_FILE="$HOME/.zshrc" ;;
  *) RC_FILE="$HOME/.bashrc" ;;
esac

SOURCE_LINE='source "$HOME/.spawn/spawn.sh"'

if ! grep -qF '.spawn/spawn.sh' "$RC_FILE" 2>/dev/null; then
  printf '\n# spawn\n%s\n' "$SOURCE_LINE" >> "$RC_FILE"
fi

printf '✅ spawn installed successfully (v%s)\n' "$VERSION"
printf '\n💡 Pro tip: if you use the default nested layout, add worktrees to your .gitignore:\n   echo ".worktrees/" >> .gitignore\n'

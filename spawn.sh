#!/usr/bin/env bash

# spawn runtime loader

_spawn_is_sourced=0
if [[ -n "${ZSH_VERSION:-}" ]]; then
  case "${ZSH_EVAL_CONTEXT:-}" in
    *:file) _spawn_is_sourced=1 ;;
  esac
elif [[ -n "${BASH_VERSION:-}" ]]; then
  [[ "${BASH_SOURCE[0]}" != "$0" ]] && _spawn_is_sourced=1
fi

if [[ -n "${BASH_VERSION:-}" ]]; then
  _spawn_entry_file="${BASH_SOURCE[0]}"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  _spawn_entry_file="${(%):-%N}"
else
  _spawn_entry_file="$0"
fi

case "$_spawn_entry_file" in
  /*) ;;
  *) _spawn_entry_file="$(pwd -P)/$_spawn_entry_file" ;;
esac

while [[ -L "$_spawn_entry_file" ]]; do
  _spawn_entry_dir="$(CDPATH= cd -- "$(dirname -- "$_spawn_entry_file")" && pwd -P)"
  _spawn_link_target="$(readlink -- "$_spawn_entry_file")"
  if [[ "$_spawn_link_target" == /* ]]; then
    _spawn_entry_file="$_spawn_link_target"
  else
    _spawn_entry_file="$_spawn_entry_dir/$_spawn_link_target"
  fi
done

_SPAWN_ENTRY_FILE="$_spawn_entry_file"

_SPAWN_RUNTIME_DIR="$(CDPATH= cd -- "$(dirname -- "$_spawn_entry_file")" && pwd -P)"
unset _spawn_entry_dir _spawn_link_target _spawn_entry_file

for _spawn_runtime_file in \
  "$_SPAWN_RUNTIME_DIR/lib/spawn-core.sh" \
  "$_SPAWN_RUNTIME_DIR/lib/spawn-commands.sh" \
  "$_SPAWN_RUNTIME_DIR/lib/spawn-completion.sh"
do
  if [[ ! -f "$_spawn_runtime_file" ]]; then
    echo "spawn: missing runtime file: $_spawn_runtime_file" >&2
    unset _spawn_runtime_file _SPAWN_RUNTIME_DIR
    return 1 2>/dev/null || exit 1
  fi

  # shellcheck disable=SC1090
  source "$_spawn_runtime_file"
done

unset _spawn_runtime_file _SPAWN_RUNTIME_DIR

if [[ "$_spawn_is_sourced" -eq 0 ]]; then
  if [[ "${1:-}" == "cd" ]]; then
    _spawn_error "'spawn cd' requires shell integration"
    echo "Run 'eval \"\$(spawn shell-init bash)\"' or 'eval \"\$(spawn shell-init zsh)\"' first." >&2
    exit 1
  fi

  spawn "$@"
  exit $?
fi

unset _spawn_is_sourced

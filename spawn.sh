# spawn runtime loader

if [[ -n "${BASH_VERSION:-}" ]]; then
  _spawn_entry_file="${BASH_SOURCE[0]}"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  _spawn_entry_file="${(%):-%N}"
else
  _spawn_entry_file="$0"
fi

_SPAWN_RUNTIME_DIR="$(CDPATH= cd -- "$(dirname -- "$_spawn_entry_file")" && pwd -P)"
unset _spawn_entry_file

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

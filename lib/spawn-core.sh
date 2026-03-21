SPAWN_HOME="$HOME/.spawn"
SPAWN_VERSION="unknown"
[[ -f "$SPAWN_HOME/VERSION" ]] && SPAWN_VERSION="$(<"$SPAWN_HOME/VERSION")"

_spawn_print_main_usage() {
  cat <<'EOF'
Usage:
  spawn <command> [options]

Commands:
  new       Create a worktree + branch, then open the selected agent
  start     Reopen an existing worktree in the selected agent
  cd        Jump to a worktree directory or back to the repo root
  ls        List spawn-managed worktrees
  merge     Merge a worktree branch into the primary checkout
  rm        Remove one worktree, or all of them with --all
  init      Open an agent to create the repo setup hook
  config    Show or update spawn configuration
  update    Refresh the installed spawn runtime from the local source
  version   Print the installed spawn version

Examples:
  spawn new feature/auth
  spawn new feature/auth -a claude -p "Continue from the API refactor"
  spawn start feature/auth
  spawn merge feature/auth --squash
  spawn config set layout sibling

Run:
  spawn <command> --help
EOF
}

_spawn_print_new_usage() {
  cat <<'EOF'
Usage:
  spawn new <branch> [-a <agent>] [-b] [-f <base-branch>] [-p <prompt>]

Description:
  Creates a new branch and worktree, then opens the selected agent
  in an interactive session.

Options:
  -a, --agent <agent>   Agent to launch: claude or codex
  -b, --bypass          Skip permission prompts for the selected agent
  -f, --from <branch>   Base branch or ref to branch from
  -p <prompt>           Seed the first interactive message

Defaults:
  agent: claude
  base:  current HEAD

Environment:
  SPAWN_AGENT=claude|codex
  SPAWN_BYPASS=1

Examples:
  spawn new feature/auth
  spawn new feature/auth -f develop
  spawn new feature/auth -a codex -p "Pick up from the auth cleanup"
EOF
}

_spawn_print_start_usage() {
  cat <<'EOF'
Usage:
  spawn start <branch> [-a <agent>] [-b] [-p <prompt>]

Description:
  Opens an existing worktree and resumes the most recent session for that
  worktree in the selected agent.

Options:
  -a, --agent <agent>   Agent to launch: claude or codex
  -b, --bypass          Skip permission prompts for the selected agent
  -p <prompt>           Seed the first interactive message

Defaults:
  agent: claude

Environment:
  SPAWN_AGENT=claude|codex
  SPAWN_BYPASS=1

Examples:
  spawn start feature/auth
  spawn start feature/auth -a codex
EOF
}

_spawn_print_cd_usage() {
  cat <<'EOF'
Usage:
  spawn cd [branch]

Description:
  Changes into a spawn-managed worktree directory.
  With no branch, jumps back to the main repository root.

Examples:
  spawn cd
  spawn cd feature/auth
EOF
}

_spawn_print_ls_usage() {
  cat <<'EOF'
Usage:
  spawn ls

Description:
  Lists spawn-managed branches for the current repository.
EOF
}

_spawn_print_merge_usage() {
  cat <<'EOF'
Usage:
  spawn merge [branch] [--squash]

Description:
  Merges a worktree branch into the primary checkout.
  If no branch is given, spawn tries to infer it from the current worktree.

Options:
  --squash   Stage the merge result as a single squashed change

Examples:
  spawn merge feature/auth
  spawn merge feature/auth --squash
EOF
}

_spawn_print_rm_usage() {
  cat <<'EOF'
Usage:
  spawn rm [branch] [-f|--force]
  spawn rm --all

Description:
  Removes a worktree and deletes its branch.
  If no branch is given, spawn tries to infer it from the current worktree.

Options:
  -f, --force   Remove even if the worktree has uncommitted changes
  --all         Remove every spawn-managed worktree after confirmation

Examples:
  spawn rm feature/auth
  spawn rm --force feature/auth
  spawn rm --all
EOF
}

_spawn_print_init_usage() {
  cat <<'EOF'
Usage:
  spawn init [-a <agent>] [--replace]

Description:
  Opens the selected agent in an interactive session with a prompt to inspect
  the repository and create the shared setup hook.

Options:
  -a, --agent <agent>   Agent to launch: claude or codex
  --replace             Replace an existing setup hook

Defaults:
  agent: claude

Example:
  spawn init -a codex
EOF
}

_spawn_print_config_usage() {
  cat <<'EOF'
Usage:
  spawn config
  spawn config set layout <preset> [--global]

Description:
  Shows the effective layout, or updates the layout used for future worktrees.

Presets:
  nested        .worktrees/<branch> inside the repo
  outer-nested  <repo>.worktrees/<branch> next to the repo
  sibling       <repo>-<branch> next to the repo

Examples:
  spawn config
  spawn config set layout sibling
  spawn config set layout nested --global
EOF
}

_spawn_print_update_usage() {
  cat <<'EOF'
Usage:
  spawn update

Description:
  Updates the installed spawn runtime from the local source directory
  registered during install.
EOF
}

spawn() {
  local cmd="${1:-}"
  shift 2>/dev/null

  case "$cmd" in
    new)     _spawn_new "$@" ;;
    start)   _spawn_start "$@" ;;
    cd)      _spawn_cd "$@" ;;
    ls)      _spawn_ls "$@" ;;
    merge)   _spawn_merge "$@" ;;
    rm)      _spawn_rm "$@" ;;
    init)    _spawn_init "$@" ;;
    config)  _spawn_config "$@" ;;
    update)  _spawn_update "$@" ;;
    version) echo "spawn $SPAWN_VERSION" ;;
    --help|-h|"")
      _spawn_print_main_usage
      return 0
      ;;
    *)
      echo "Unknown command: $cmd"
      echo "Run 'spawn --help' for usage."
      return 1
      ;;
  esac
}

_spawn_repo_root() {
  local git_common_dir
  git_common_dir="$(git rev-parse --git-common-dir 2>/dev/null)" || return 1
  (CDPATH= cd -- "$(dirname -- "$git_common_dir")" && pwd -P)
}

_spawn_safe_name() {
  printf '%s\n' "${1//\//-}"
}

_spawn_source_dir() {
  local source_file="$SPAWN_HOME/SOURCE_DIR"
  [[ -f "$source_file" ]] || return 1

  local source_dir
  source_dir="$(<"$source_file")"
  [[ -n "$source_dir" && -d "$source_dir" ]] || return 1
  printf '%s\n' "$source_dir"
}

_spawn_source_version() {
  local source_dir
  source_dir="$(_spawn_source_dir)" || return 1
  [[ -f "$source_dir/VERSION" ]] || return 1
  tr -d '[:space:]' < "$source_dir/VERSION"
}

_spawn_global_config_file() {
  printf '%s\n' "$SPAWN_HOME/config.json"
}

_spawn_repo_common_dir() {
  local repo_root="$1"
  local git_common_dir

  git_common_dir="$(git -C "$repo_root" rev-parse --git-common-dir 2>/dev/null)" || return 1
  if [[ "$git_common_dir" != /* ]]; then
    git_common_dir="$repo_root/$git_common_dir"
  fi

  (CDPATH= cd -- "$git_common_dir" && pwd -P)
}

_spawn_repo_state_dir() {
  local repo_root="$1"
  local common_dir

  common_dir="$(_spawn_repo_common_dir "$repo_root")" || return 1
  printf '%s\n' "$common_dir/spawn"
}

_spawn_repo_config_file() {
  local repo_root="$1"
  local state_dir

  state_dir="$(_spawn_repo_state_dir "$repo_root")" || return 1
  printf '%s\n' "$state_dir/config.json"
}

_spawn_repo_hook_file() {
  local repo_root="$1"
  local hook_name="$2"
  local state_dir

  state_dir="$(_spawn_repo_state_dir "$repo_root")" || return 1
  printf '%s\n' "$state_dir/$hook_name"
}

_spawn_read_layout_from_file() {
  local config_file="$1"
  [[ -f "$config_file" ]] || return 1
  grep '"layout"' "$config_file" 2>/dev/null | sed 's/.*"layout"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true
}

_spawn_get_layout() {
  local repo_root="$1"
  local layout=""
  local repo_config_file=""
  local global_config_file

  if [[ -n "$repo_root" ]]; then
    repo_config_file="$(_spawn_repo_config_file "$repo_root" 2>/dev/null || true)"
  fi

  if [[ -n "$repo_config_file" ]]; then
    layout="$(_spawn_read_layout_from_file "$repo_config_file")"
  fi

  global_config_file="$(_spawn_global_config_file)"
  if [[ -z "$layout" && -f "$global_config_file" ]]; then
    layout="$(_spawn_read_layout_from_file "$global_config_file")"
  fi

  printf '%s\n' "${layout:-nested}"
}

_spawn_worktree_base() {
  local repo_root="$1"
  local layout
  layout="$(_spawn_get_layout "$repo_root")"

  case "$layout" in
    outer-nested) printf '%s\n' "$(dirname "$repo_root")/$(basename "$repo_root").worktrees" ;;
    sibling) printf '%s\n' "$(dirname "$repo_root")" ;;
    *) printf '%s\n' "$repo_root/.worktrees" ;;
  esac
}

_spawn_worktree_dir() {
  local repo_root="$1"
  local safe_name
  safe_name="$(_spawn_safe_name "$2")"

  case "$(_spawn_get_layout "$repo_root")" in
    outer-nested) printf '%s\n' "$(dirname "$repo_root")/$(basename "$repo_root").worktrees/$safe_name" ;;
    sibling) printf '%s\n' "$(dirname "$repo_root")/$(basename "$repo_root")-$safe_name" ;;
    *) printf '%s\n' "$repo_root/.worktrees/$safe_name" ;;
  esac
}

_spawn_detect_worktree_branch() {
  local repo_root="$1"
  local layout
  local base=""
  local safe_name=""
  local wt_dir=""

  layout="$(_spawn_get_layout "$repo_root")"

  case "$layout" in
    outer-nested)
      base="$(dirname "$repo_root")/$(basename "$repo_root").worktrees"
      if [[ "$PWD" == "$base/"* ]]; then
        safe_name="${PWD#$base/}"
        safe_name="${safe_name%%/*}"
        wt_dir="$base/$safe_name"
      fi
      ;;
    sibling)
      local repo_name parent check_dir current_dir
      repo_name="$(basename "$repo_root")"
      parent="$(dirname "$repo_root")"
      check_dir="$PWD"

      while [[ "$(dirname "$check_dir")" != "$parent" && "$check_dir" != "/" ]]; do
        check_dir="$(dirname "$check_dir")"
      done

      current_dir="$(basename "$check_dir")"
      if [[ "$current_dir" == "${repo_name}-"* && "$check_dir" != "$repo_root" ]]; then
        safe_name="${current_dir#${repo_name}-}"
        wt_dir="$parent/$current_dir"
      fi
      ;;
    *)
      if [[ "$PWD" == */.worktrees/* ]]; then
        safe_name="${PWD##*/.worktrees/}"
        safe_name="${safe_name%%/*}"
        wt_dir="$repo_root/.worktrees/$safe_name"
      fi
      ;;
  esac

  [[ -n "$safe_name" ]] || return 1

  git -C "$repo_root" worktree list --porcelain \
    | grep -A2 "^worktree ${wt_dir}\$" \
    | grep '^branch ' \
    | sed 's|^branch refs/heads/||'
}

_spawn_spinner_start() {
  [[ -n "${ZSH_VERSION:-}" ]] && setopt localoptions nomonitor
  (
    while true; do
      for c in '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'; do
        printf '\b%s' "$c"
        sleep 0.08
      done
    done
  ) &
  _SPAWN_SPINNER_PID=$!
}

_spawn_spinner_stop() {
  [[ -n "$_SPAWN_SPINNER_PID" ]] || return
  [[ -n "${ZSH_VERSION:-}" ]] && setopt localoptions nomonitor
  kill "$_SPAWN_SPINNER_PID" 2>/dev/null
  wait "$_SPAWN_SPINNER_PID" 2>/dev/null
  printf '\b \n'
  unset _SPAWN_SPINNER_PID
}

_spawn_current_head() {
  git rev-parse --verify HEAD 2>/dev/null
}

_spawn_resolve_start_point() {
  local from_ref="$1"

  if [[ -n "$from_ref" ]]; then
    git rev-parse --verify "${from_ref}^{commit}" 2>/dev/null || {
      echo "Could not resolve base ref: $from_ref"
      return 1
    }
    return 0
  fi

  _spawn_current_head || {
    echo "Could not determine the current HEAD."
    return 1
  }
}

_spawn_require_claude() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "claude CLI not found. Install it: https://code.claude.com/docs/en/quickstart"
    return 1
  fi
}

_spawn_require_codex() {
  if ! command -v codex >/dev/null 2>&1; then
    echo "codex CLI not found. Install it: https://openai.com/es-419/codex"
    return 1
  fi
}

_spawn_default_agent() {
  printf '%s\n' "${SPAWN_AGENT:-claude}"
}

_spawn_validate_agent() {
  case "$1" in
    claude|codex) return 0 ;;
    *)
      echo "Invalid agent: $1"
      echo "Valid agents: claude, codex"
      return 1
      ;;
  esac
}

_spawn_parse_session_args() {
  local mode="$1"
  shift

  _SPAWN_SESSION_BRANCH=""
  _SPAWN_SESSION_PROMPT=""
  _SPAWN_SESSION_BYPASS="${SPAWN_BYPASS:-}"
  _SPAWN_SESSION_AGENT="$(_spawn_default_agent)"
  _SPAWN_SESSION_FROM=""

  local -a branch_words=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -b|--bypass)
        _SPAWN_SESSION_BYPASS=1
        shift
        ;;
      -f|--from)
        if [[ "$mode" != "new" ]]; then
          echo "Option $1 is only supported by 'spawn new'."
          return 1
        fi
        if [[ $# -lt 2 ]]; then
          echo "Missing value for $1."
          return 1
        fi
        _SPAWN_SESSION_FROM="$2"
        shift 2
        ;;
      -a|--agent)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for $1."
          return 1
        fi
        _SPAWN_SESSION_AGENT="$2"
        shift 2
        ;;
      -p)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for -p."
          return 1
        fi
        _SPAWN_SESSION_PROMPT="$2"
        shift 2
        ;;
      --)
        shift
        while [[ $# -gt 0 ]]; do
          branch_words+=("$1")
          shift
        done
        ;;
      -*)
        echo "Unknown option: $1"
        return 1
        ;;
      *)
        if [[ "$mode" == "new" ]]; then
          branch_words+=("$1")
        else
          if [[ -n "$_SPAWN_SESSION_BRANCH" ]]; then
            echo "Too many arguments."
            return 1
          fi
          _SPAWN_SESSION_BRANCH="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$mode" == "new" ]]; then
    local IFS='-'
    _SPAWN_SESSION_BRANCH="${branch_words[*]}"
  fi

  _spawn_validate_agent "$_SPAWN_SESSION_AGENT" || return 1
  [[ -n "$_SPAWN_SESSION_BRANCH" ]]
}

_spawn_run_agent() {
  local agent="$1"
  local mode="$2"
  local prompt="$3"
  local bypass="$4"
  local -a cmd=()

  case "$agent" in
    claude)
      _spawn_require_claude || return 1
      [[ -n "$bypass" ]] && cmd+=(--dangerously-skip-permissions)
      [[ "$mode" == "continue" ]] && cmd+=(-c)
      [[ -n "$prompt" ]] && cmd+=("$prompt")
      claude "${cmd[@]}"
      ;;
    codex)
      _spawn_require_codex || return 1
      if [[ "$mode" == "continue" ]]; then
        cmd=(resume --last)
      fi
      [[ -n "$bypass" ]] && cmd+=(--yolo)
      [[ -n "$prompt" ]] && cmd+=("$prompt")
      codex "${cmd[@]}"
      ;;
  esac
}

_spawn_run_hook() {
  local hook_name="$1"
  local repo_root="$2"
  local repo_hook

  repo_hook="$(_spawn_repo_hook_file "$repo_root" "$hook_name")" || return 1

  if [[ -x "$repo_hook" ]]; then
    "$repo_hook"
    return 0
  fi

  return 1
}

_spawn_git_stdout_quiet() {
  git "$@" >/dev/null
}

_spawn_sync_runtime() {
  local source_dir="$1"
  local target_dir="$2"
  local tmp_dir

  [[ -f "$source_dir/spawn.sh" ]] || return 1
  [[ -f "$source_dir/VERSION" ]] || return 1
  [[ -d "$source_dir/lib" ]] || return 1

  tmp_dir="$(mktemp -d)" || return 1

  cp "$source_dir/spawn.sh" "$tmp_dir/spawn.sh" || { rm -rf "$tmp_dir"; return 1; }
  cp "$source_dir/VERSION" "$tmp_dir/VERSION" || { rm -rf "$tmp_dir"; return 1; }
  cp -R "$source_dir/lib" "$tmp_dir/lib" || { rm -rf "$tmp_dir"; return 1; }

  mkdir -p "$target_dir"
  mv "$tmp_dir/spawn.sh" "$target_dir/spawn.sh" || { rm -rf "$tmp_dir"; return 1; }
  mv "$tmp_dir/VERSION" "$target_dir/VERSION" || { rm -rf "$tmp_dir"; return 1; }
  rm -rf "$target_dir/lib"
  mv "$tmp_dir/lib" "$target_dir/lib" || { rm -rf "$tmp_dir"; return 1; }
  rmdir "$tmp_dir" 2>/dev/null || true
}

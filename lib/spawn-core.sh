SPAWN_HOME="$HOME/.spawn"

_spawn_runtime_version() {
  if [[ -n "${_SPAWN_ENTRY_FILE:-}" ]]; then
    local runtime_dir
    runtime_dir="$(CDPATH= cd -- "$(dirname -- "$_SPAWN_ENTRY_FILE")" && pwd -P 2>/dev/null)" || runtime_dir=""

    local package_file="$runtime_dir/package.json"
    if [[ -f "$package_file" ]]; then
      local package_version
      package_version="$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$package_file")"
      [[ -n "$package_version" ]] && {
        printf '%s\n' "$package_version"
        return 0
      }
    fi
  fi

  [[ -f "$SPAWN_HOME/VERSION" ]] && {
    printf '%s\n' "$(<"$SPAWN_HOME/VERSION")"
    return 0
  }

  printf '%s\n' "unknown"
}

SPAWN_VERSION="$(_spawn_runtime_version)"

_spawn_has_color() { [[ -t 1 && "${NO_COLOR:-}" == "" ]]; }
_spawn_bold()  { _spawn_has_color && printf '\033[1m%s\033[0m' "$*" || printf '%s' "$*"; }
_spawn_dim()   { _spawn_has_color && printf '\033[2m%s\033[0m' "$*" || printf '%s' "$*"; }
_spawn_green() { _spawn_has_color && printf '\033[32m%s\033[0m' "$*" || printf '%s' "$*"; }
_spawn_cyan()  { _spawn_has_color && printf '\033[36m%s\033[0m' "$*" || printf '%s' "$*"; }
_spawn_error() { printf 'spawn: %s\n' "$*" >&2; }

_spawn_print_main_usage() {
  _spawn_bold "spawn v$SPAWN_VERSION"; echo " — Parallel AI agent sessions via git worktrees"
  cat <<'EOF'

USAGE
  spawn <command> [options]

COMMANDS
  new       Create a worktree + branch, then open the agent
  start     Resume an existing worktree session
  status    Show worktree states and active agent sessions
  ls        List spawn-managed worktrees
  cd        Jump to a worktree directory (no args → repo root)
  config    Show or update spawn configuration
  merge     Merge a worktree branch into the primary checkout
  rm        Remove a worktree and its branch
  init      Generate a setup hook for new worktrees
  update    Check npm for updates and self-update
  version   Print the installed version

EXAMPLES
  spawn new feature/auth -p "Add OAuth2 login"
  spawn start feature/auth
  spawn merge feature/auth --squash
  spawn rm feature/auth

Run 'spawn <command> --help' for details on a specific command.
EOF
}

_spawn_print_new_usage() {
  cat <<'EOF'
Usage:
  spawn new <branch> [-a <agent>] [-b] [-f <base-branch>] [-p <text>]

Description:
  Creates a new branch and worktree, then opens the selected agent
  in an interactive session.

Options:
  -a, --agent <agent>   Agent to launch: claude or codex
  -b, --bypass          Skip permission prompts for the selected agent
  -f, --from <branch>   Base branch or ref to branch from
  -p, --prompt <text>   Seed the first interactive message

Defaults:
  agent: claude
  base:  current HEAD

Environment:
  SPAWN_AGENT=claude|codex
  SPAWN_BYPASS=1

Examples:
  spawn new feature/rest-performance
  spawn new feature/rest-performance -f develop
  spawn new feature/rest-performance -a codex -p "Optimize the GET /users endpoint"
EOF
}

_spawn_print_start_usage() {
  cat <<'EOF'
Usage:
  spawn start <branch> [-a <agent>] [-b] [-p <text>]

Description:
  Opens an existing worktree and resumes the most recent session for that
  worktree in the selected agent.

Options:
  -a, --agent <agent>   Agent to launch: claude or codex
  -b, --bypass          Skip permission prompts for the selected agent
  -p, --prompt <text>   Seed the first interactive message

Defaults:
  agent: claude

Environment:
  SPAWN_AGENT=claude|codex
  SPAWN_BYPASS=1

Examples:
  spawn start feature/rest-performance
  spawn start feature/rest-performance -a codex
EOF
}

_spawn_print_status_usage() {
  cat <<'EOF'
Usage:
  spawn status

Description:
  Shows the state of each spawn-managed worktree: branch, path,
  whether an agent is running, and last activity.
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
  spawn cd feature/rest-performance
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
  spawn merge feature/rest-performance
  spawn merge feature/rest-performance --squash
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
  spawn rm feature/rest-performance
  spawn rm --force feature/rest-performance
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
  Checks for a newer version on npm and updates if available.
EOF
}

spawn() {
  local cmd="${1:-}"
  shift 2>/dev/null

  case "$cmd" in
    new)     _spawn_new "$@" ;;
    start)   _spawn_start "$@" ;;
    status)  _spawn_status "$@" ;;
    cd)      _spawn_cd "$@" ;;
    ls)      _spawn_ls "$@" ;;
    merge)   _spawn_merge "$@" ;;
    rm)      _spawn_rm "$@" ;;
    init)    _spawn_init "$@" ;;
    config)  _spawn_config "$@" ;;
    update)  _spawn_update "$@" ;;
    version) _spawn_version ;;
    --help|-h|"")
      _spawn_print_main_usage
      return 0
      ;;
    *)
      _spawn_error "unknown command: $cmd"
      echo "Run 'spawn --help' for usage." >&2
      return 1
      ;;
  esac
}

_spawn_repo_root() {
  local git_common_dir
  git_common_dir="$(git rev-parse --git-common-dir 2>/dev/null)" || return 1
  local parent_dir="${git_common_dir%/*}"
  [[ "$parent_dir" == "$git_common_dir" ]] && parent_dir="."
  (CDPATH= cd -- "$parent_dir" && pwd -P)
}

_spawn_safe_name() {
  printf '%s\n' "${1//\//-}"
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
  local line
  while IFS= read -r line; do
    if [[ "$line" == *'"layout"'* ]]; then
      line="${line#*\"layout\"}"
      line="${line#*\"}"
      line="${line%%\"*}"
      printf '%s\n' "$line"
      return 0
    fi
  done < "$config_file"
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
  local layout="${2:-$(_spawn_get_layout "$repo_root")}"

  case "$layout" in
    outer-nested) printf '%s\n' "${repo_root%/*}/${repo_root##*/}.worktrees" ;;
    sibling) printf '%s\n' "${repo_root%/*}" ;;
    *) printf '%s\n' "$repo_root/.worktrees" ;;
  esac
}

_spawn_worktree_filter() {
  local repo_root="$1"
  local layout="${2:-$(_spawn_get_layout "$repo_root")}"

  case "$layout" in
    outer-nested) printf '%s\n' "${repo_root%/*}/${repo_root##*/}.worktrees/" ;;
    sibling) printf '%s\n' "${repo_root%/*}/${repo_root##*/}-" ;;
    *) printf '%s\n' "$repo_root/.worktrees/" ;;
  esac
}

_spawn_worktree_dir() {
  local repo_root="$1"
  local safe_name
  safe_name="$(_spawn_safe_name "$2")"
  local layout="${3:-$(_spawn_get_layout "$repo_root")}"

  case "$layout" in
    outer-nested) printf '%s\n' "${repo_root%/*}/${repo_root##*/}.worktrees/$safe_name" ;;
    sibling) printf '%s\n' "${repo_root%/*}/${repo_root##*/}-$safe_name" ;;
    *) printf '%s\n' "$repo_root/.worktrees/$safe_name" ;;
  esac
}

_spawn_detect_worktree_branch() {
  local repo_root="$1"
  local layout="${2:-$(_spawn_get_layout "$repo_root")}"
  local safe_name=""
  local wt_dir=""

  case "$layout" in
    outer-nested)
      local base="${repo_root%/*}/${repo_root##*/}.worktrees"
      if [[ "$PWD" == "$base/"* ]]; then
        safe_name="${PWD#$base/}"
        safe_name="${safe_name%%/*}"
        wt_dir="$base/$safe_name"
      fi
      ;;
    sibling)
      local repo_name="${repo_root##*/}"
      local parent="${repo_root%/*}"
      if [[ "$PWD" == "$parent/"* ]]; then
        local remainder="${PWD#$parent/}"
        local current_dir="${remainder%%/*}"
        if [[ "$current_dir" == "${repo_name}-"* && "$parent/$current_dir" != "$repo_root" ]]; then
          safe_name="${current_dir#${repo_name}-}"
          wt_dir="$parent/$current_dir"
        fi
      fi
      ;;
    *)
      if [[ "$PWD" == "$repo_root/.worktrees/"* ]]; then
        safe_name="${PWD#$repo_root/.worktrees/}"
        safe_name="${safe_name%%/*}"
        wt_dir="$repo_root/.worktrees/$safe_name"
      fi
      ;;
  esac

  [[ -n "$safe_name" ]] || return 1

  local _line _found=0
  while IFS= read -r _line; do
    case "$_line" in
      "worktree $wt_dir") _found=1 ;;
      "branch refs/heads/"*)
        if [[ "$_found" -eq 1 ]]; then
          printf '%s\n' "${_line#branch refs/heads/}"
          return 0
        fi
        ;;
      "") _found=0 ;;
    esac
  done < <(git -C "$repo_root" worktree list --porcelain 2>/dev/null)
  return 1
}

_spawn_spinner_start() {
  [[ -n "${ZSH_VERSION:-}" ]] && setopt localoptions nomonitor
  local msg="${1:-}"
  [[ -n "$msg" ]] && printf '%s ' "$msg"
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
  [[ -n "${_SPAWN_SPINNER_PID:-}" ]] || return
  [[ -n "${ZSH_VERSION:-}" ]] && setopt localoptions nomonitor
  kill "$_SPAWN_SPINNER_PID" 2>/dev/null
  wait "$_SPAWN_SPINNER_PID" 2>/dev/null
  printf '\b \n'
  unset _SPAWN_SPINNER_PID
}

_spawn_version() {
  _spawn_bold "spawn v$SPAWN_VERSION"; echo ""
}

_SPAWN_UPDATE_CHECK_FILE="$SPAWN_HOME/.last_update_check"

_spawn_check_update_available() {
  command -v npm >/dev/null 2>&1 || return 1

  local now
  now="$(date +%s 2>/dev/null)" || return 1
  if [[ -f "$_SPAWN_UPDATE_CHECK_FILE" ]]; then
    local last_check
    last_check="$(<"$_SPAWN_UPDATE_CHECK_FILE")"
    local elapsed=$(( now - last_check ))
    (( elapsed < 86400 )) && return 1
  fi

  local latest
  latest="$(npm view @jxtools/spawn version 2>/dev/null)" || return 1
  printf '%s\n' "$now" > "$_SPAWN_UPDATE_CHECK_FILE" 2>/dev/null || true
  [[ -n "$latest" && "$latest" != "$SPAWN_VERSION" ]] || return 1

  echo ""
  _spawn_dim "A new version of spawn is available: "
  _spawn_bold "v$latest"
  _spawn_dim " (current: v$SPAWN_VERSION)"
  echo ""
  _spawn_dim "Run '"
  _spawn_cyan "spawn update"
  _spawn_dim "' to upgrade."
  echo ""
  echo ""
}

_spawn_schedule_update_check() {
  local runtime="${_SPAWN_ENTRY_FILE:-$SPAWN_HOME/spawn.sh}"
  [[ -f "$runtime" ]] || return 0

  local shell_bin=""
  if command -v bash >/dev/null 2>&1; then
    shell_bin="$(command -v bash)"
  elif command -v zsh >/dev/null 2>&1; then
    shell_bin="$(command -v zsh)"
  else
    return 0
  fi

  "$shell_bin" -c '
    source "$1" >/dev/null 2>&1 || exit 0
    (_spawn_check_update_available || true) >/dev/tty 2>/dev/null &
  ' _ "$runtime" </dev/null >/dev/null 2>&1 || true
}

_spawn_current_head() {
  git rev-parse --verify HEAD 2>/dev/null
}

_spawn_resolve_start_point() {
  local from_ref="$1"

  if [[ -n "$from_ref" ]]; then
    git rev-parse --verify "${from_ref}^{commit}" 2>/dev/null || {
      _spawn_error "could not resolve base ref: $from_ref"
      return 1
    }
    return 0
  fi

  _spawn_current_head || {
    _spawn_error "could not determine the current HEAD"
    return 1
  }
}

_spawn_require_claude() {
  if ! command -v claude >/dev/null 2>&1; then
    _spawn_error "claude CLI not found. Install it: https://code.claude.com/docs/en/quickstart"
    return 1
  fi
}

_spawn_require_codex() {
  if ! command -v codex >/dev/null 2>&1; then
    _spawn_error "codex CLI not found. Install it: https://openai.com/es-419/codex"
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
      _spawn_error "invalid agent: $1"
      echo "Valid agents: claude, codex" >&2
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
          _spawn_error "option $1 is only supported by 'spawn new'"
          return 1
        fi
        if [[ $# -lt 2 ]]; then
          _spawn_error "missing value for $1"
          return 1
        fi
        _SPAWN_SESSION_FROM="$2"
        shift 2
        ;;
      -a|--agent)
        if [[ $# -lt 2 ]]; then
          _spawn_error "missing value for $1"
          return 1
        fi
        _SPAWN_SESSION_AGENT="$2"
        shift 2
        ;;
      -p|--prompt)
        if [[ $# -lt 2 ]]; then
          _spawn_error "missing value for $1"
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
        _spawn_error "unknown option: $1"
        return 1
        ;;
      *)
        if [[ "$mode" == "new" ]]; then
          branch_words+=("$1")
        else
          if [[ -n "$_SPAWN_SESSION_BRANCH" ]]; then
            _spawn_error "too many arguments"
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

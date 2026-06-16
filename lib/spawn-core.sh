SPAWN_HOME="$HOME/.spawn"

_spawn_package_version_from_dir() {
  local package_dir="$1"
  local package_file="$package_dir/package.json"
  [[ -f "$package_file" ]] || return 1

  local package_version
  package_version="$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$package_file")"
  [[ -n "$package_version" ]] || return 1

  printf '%s\n' "$package_version"
}

_spawn_runtime_version() {
  if [[ -n "${_SPAWN_ENTRY_FILE:-}" ]]; then
    local runtime_dir
    runtime_dir="$(CDPATH= cd -- "$(dirname -- "$_SPAWN_ENTRY_FILE")" && pwd -P 2>/dev/null)" || runtime_dir=""
    _spawn_package_version_from_dir "$runtime_dir" && return 0
  fi

  [[ -f "$SPAWN_HOME/VERSION" ]] && {
    printf '%s\n' "$(<"$SPAWN_HOME/VERSION")"
    return 0
  }

  printf '%s\n' "unknown"
}

SPAWN_VERSION="$(_spawn_runtime_version)"

_spawn_global_package_dir() {
  local npm_root
  npm_root="$(npm root -g 2>/dev/null)" || return 1
  printf '%s\n' "$npm_root/@jxtools/spawn"
}

_spawn_version_key() {
  local version="${1%%-*}"
  # Guard against non-numeric versions (e.g. "unknown") to avoid arithmetic errors
  [[ "$version" =~ ^[0-9]+([.][0-9]+){0,3}$ ]] || version=0
  local major=0 minor=0 patch=0 extra=0
  IFS=. read -r major minor patch extra <<< "$version"
  printf '%08d%08d%08d%08d\n' \
    "$((10#${major:-0}))" \
    "$((10#${minor:-0}))" \
    "$((10#${patch:-0}))" \
    "$((10#${extra:-0}))"
}

_spawn_version_is_newer() {
  local candidate="$1"
  local current="$2"
  [[ "$(_spawn_version_key "$candidate")" > "$(_spawn_version_key "$current")" ]]
}

_spawn_saved_registry_file() {
  printf '%s\n' "$SPAWN_HOME/registry"
}

_spawn_saved_registry() {
  local registry_file
  registry_file="$(_spawn_saved_registry_file)"
  [[ -f "$registry_file" ]] || return 1

  local registry
  registry="$(<"$registry_file")"
  [[ -n "$registry" ]] || return 1
  printf '%s\n' "$registry"
}

_spawn_npm_registry() {
  if [[ -n "${npm_config_registry:-}" ]]; then
    printf '%s\n' "$npm_config_registry"
    return 0
  fi

  if [[ -n "${NPM_CONFIG_REGISTRY:-}" ]]; then
    printf '%s\n' "$NPM_CONFIG_REGISTRY"
    return 0
  fi

  _spawn_saved_registry && return 0

  local registry
  registry="$(npm config get registry 2>/dev/null || true)"
  [[ -n "$registry" && "$registry" != "undefined" && "$registry" != "null" ]] || return 1
  printf '%s\n' "$registry"
}

_spawn_npm_view_latest_version() {
  local registry
  registry="$(_spawn_npm_registry 2>/dev/null || true)"

  if [[ -n "$registry" ]]; then
    npm_config_fetch_retries=0 npm_config_fetch_timeout=5000 \
      npm view @jxtools/spawn version --registry "$registry" 2>/dev/null
  else
    npm_config_fetch_retries=0 npm_config_fetch_timeout=5000 \
      npm view @jxtools/spawn version 2>/dev/null
  fi
}

_spawn_npm_install_latest() {
  local registry
  registry="$(_spawn_npm_registry 2>/dev/null || true)"

  if [[ -n "$registry" ]]; then
    npm_config_fetch_retries=0 npm_config_fetch_timeout=10000 \
      npm install -g @jxtools/spawn@latest --registry "$registry" >/dev/null 2>&1
  else
    npm_config_fetch_retries=0 npm_config_fetch_timeout=10000 \
      npm install -g @jxtools/spawn@latest >/dev/null 2>&1
  fi
}

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
  spawn new [<branch>] [-a <agent>] [-b] [-f <base-branch>] [-p <text>]

Description:
  Creates a new branch and worktree, then opens the selected agent
  in an interactive session.
  If no branch is given, uses the current branch (requires an attached HEAD).

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
  spawn new                                    # uses current branch
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
  spawn status [--all]

Description:
  Shows the state of each spawn-managed worktree: branch, path,
  whether an agent is running, and last activity.

Options:
  --all   Show active spawn sessions across all repositories
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

_spawn_require_repo_root() {
  local repo_root
  repo_root="$(_spawn_repo_root)" || {
    _spawn_error "not in a git repo"
    return 1
  }
  printf '%s\n' "$repo_root"
}

# Discover repo roots when not inside a git repo.
# 1. Look for *.worktrees dirs in $PWD → infer repo (foo.worktrees → foo)
# 2. Look for sibling dirs that look like repo-branch patterns
# 3. Fallback to registered repos whose worktree base is under $PWD
_spawn_discover_repo_roots() {
  local found=""
  local dir
  dir="$(pwd -P)"
  local wt_dir candidate canon

  # Strategy 1: *.worktrees directories in current dir → outer-nested layout
  while IFS= read -r -d '' wt_dir; do
    [[ -d "$wt_dir" ]] || continue
    candidate="${wt_dir%.worktrees}"
    [[ -d "$candidate" ]] || continue
    git -C "$candidate" rev-parse --git-dir >/dev/null 2>&1 || continue
    canon="$(CDPATH= cd -- "$candidate" && pwd -P)" || continue
    case $'\n'"$found" in *$'\n'"$canon"$'\n'*) continue ;; esac
    found+="${canon}"$'\n'
  done < <(find "$dir" -maxdepth 1 -name '*.worktrees' -type d -print0 2>/dev/null)

  # Strategy 2: registered repos whose worktree base is under current dir
  local registry="$SPAWN_HOME/repos"
  if [[ -f "$registry" ]]; then
    local _repo _canon_repo
    while IFS= read -r _repo; do
      [[ -n "$_repo" && -d "$_repo" ]] || continue
      _canon_repo="$(CDPATH= cd -- "$_repo" && pwd -P)" || continue
      case $'\n'"$found" in *$'\n'"$_canon_repo"$'\n'*) continue ;; esac
      [[ "${_canon_repo%/*}" == "$dir" ]] || continue
      git -C "$_canon_repo" rev-parse --git-dir >/dev/null 2>&1 || continue
      found+="${_canon_repo}"$'\n'
    done < "$registry"
  fi

  [[ -n "$found" ]] || return 1
  printf '%s' "$found"
}

# Try _spawn_repo_root first, then discover.
# Returns a single repo root (first found).
_spawn_resolve_repo_root() {
  local repo_root
  repo_root="$(_spawn_repo_root 2>/dev/null)" && {
    printf '%s\n' "$repo_root"
    return 0
  }

  local discovered
  discovered="$(_spawn_discover_repo_roots 2>/dev/null)" || {
    _spawn_error "not in a git repo and no spawn repositories found in this directory"
    return 1
  }

  # Return first discovered repo
  local first
  first="$(head -1 <<< "$discovered")"
  printf '%s\n' "$first"
}

# Like _spawn_resolve_repo_root but returns ALL discovered repos (one per line).
_spawn_resolve_all_repo_roots() {
  local repo_root
  repo_root="$(_spawn_repo_root 2>/dev/null)" && {
    printf '%s\n' "$repo_root"
    return 0
  }

  _spawn_discover_repo_roots 2>/dev/null || {
    _spawn_error "not in a git repo and no spawn repositories found in this directory"
    return 1
  }
}

_spawn_find_worktree_repo() {
  local branch="$1" skip_repo="${2:-}"
  local registry="$SPAWN_HOME/repos"
  [[ -f "$registry" ]] || return 1

  local _repo _layout _dir
  while IFS= read -r _repo; do
    [[ -n "$_repo" && -d "$_repo" ]] || continue
    [[ "$_repo" != "$skip_repo" ]] || continue
    git -C "$_repo" rev-parse --git-dir >/dev/null 2>&1 || continue
    _layout="$(_spawn_get_layout "$_repo")"
    _dir="$(_spawn_worktree_dir "$_repo" "$branch" "$_layout")"
    if [[ -d "$_dir" ]]; then
      printf '%s\n' "$_repo"
      return 0
    fi
  done < "$registry"
  return 1
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
      case "$line" in
        nested|outer-nested|sibling)
          printf '%s\n' "$line"
          return 0
          ;;
        *)
          return 1
          ;;
      esac
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

_spawn_spawn_worktree_pairs() {
  local repo_root="$1"
  local layout="${2:-$(_spawn_get_layout "$repo_root")}"
  local filter
  filter="$(_spawn_worktree_filter "$repo_root" "$layout")"

  local line wt_dir="" wt_branch=""
  while IFS= read -r line; do
    case "$line" in
      "worktree "*)
        wt_dir="${line#worktree }"
        wt_branch=""
        ;;
      "branch refs/heads/"*)
        wt_branch="${line#branch refs/heads/}"
        [[ "$wt_dir" == "$filter"* ]] && printf '%s\t%s\n' "$wt_dir" "$wt_branch"
        ;;
    esac
  done < <(git -C "$repo_root" worktree list --porcelain 2>/dev/null)
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

# Print the branch checked out at a specific worktree directory, if any.
# Used to detect sanitized-name collisions (e.g. "feature/x" and "feature-x"
# both map to the dir ".worktrees/feature-x"). Returns 1 when the directory
# is not a registered worktree or is on a detached HEAD.
_spawn_branch_at_worktree() {
  local repo_root="$1" target_dir="$2"
  local _line _cur=""
  while IFS= read -r _line; do
    case "$_line" in
      "worktree "*) _cur="${_line#worktree }" ;;
      "branch refs/heads/"*)
        if [[ "$_cur" == "$target_dir" ]]; then
          printf '%s\n' "${_line#branch refs/heads/}"
          return 0
        fi
        ;;
    esac
  done < <(git -C "$repo_root" worktree list --porcelain 2>/dev/null)
  return 1
}

# Fail when a requested branch resolves to a worktree dir already held by a
# different branch (sanitized-name collision). $3 is the verb for the hint.
_spawn_guard_branch_collision() {
  local repo_root="$1" worktree_dir="$2" branch="$3" verb="${4:-use}"
  [[ -d "$worktree_dir" ]] || return 0
  local actual_branch
  actual_branch="$(_spawn_branch_at_worktree "$repo_root" "$worktree_dir" 2>/dev/null || true)"
  [[ -n "$actual_branch" && "$actual_branch" != "$branch" ]] || return 0
  _spawn_error "'$branch' resolves to a worktree on branch '$actual_branch'"
  echo "Branch names with '/' appear as '-' in the WORKTREE column; pass the BRANCH name." >&2
  echo "Did you mean 'spawn $verb $actual_branch'?" >&2
  return 1
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
  latest="$(_spawn_npm_view_latest_version)" || return 1
  printf '%s\n' "$now" > "$_SPAWN_UPDATE_CHECK_FILE" 2>/dev/null || true
  [[ -n "$latest" ]] || return 1
  _spawn_version_is_newer "$latest" "$SPAWN_VERSION" || return 1

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

_spawn_clear_session_args() {
  unset \
    _SPAWN_SESSION_BRANCH \
    _SPAWN_SESSION_PROMPT \
    _SPAWN_SESSION_BYPASS \
    _SPAWN_SESSION_AGENT \
    _SPAWN_SESSION_FROM
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

  _spawn_clear_session_args
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
    if [[ -z "$_SPAWN_SESSION_BRANCH" && -n "$_SPAWN_SESSION_FROM" ]]; then
      _SPAWN_SESSION_BRANCH="$_SPAWN_SESSION_FROM"
    fi
  fi

  _spawn_validate_agent "$_SPAWN_SESSION_AGENT" || return 1
  if [[ -z "$_SPAWN_SESSION_BRANCH" && "$mode" != "new" ]]; then
    _spawn_error "missing branch name"
    return 1
  fi
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
  local worktree_dir="$3"
  local repo_hook

  repo_hook="$(_spawn_repo_hook_file "$repo_root" "$hook_name")" || return 1

  if [[ -x "$repo_hook" ]]; then
    "$repo_hook" "$repo_root" "$worktree_dir"
    return 0
  fi

  return 1
}

_spawn_git_stdout_quiet() {
  git "$@" >/dev/null
}

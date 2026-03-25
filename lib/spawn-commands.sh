_spawn_offer_gitignore() {
  local repo_root="$1" worktree_dir="$2" layout="$3"
  [[ "$layout" == "nested" ]] || return 0
  local worktree_gitignore="$worktree_dir/.gitignore"
  [[ -f "$worktree_gitignore" ]] && grep -qF '.worktrees' "$worktree_gitignore" 2>/dev/null && return 0

  local state_dir answer_file saved_answer
  state_dir="$(_spawn_repo_state_dir "$repo_root" 2>/dev/null)" || return 0
  answer_file="$state_dir/worktrees-gitignore-answer"
  saved_answer=""
  [[ -f "$answer_file" ]] && saved_answer="$(<"$answer_file")"

  case "$saved_answer" in
    yes)
      printf '%s\n' '.worktrees/' >> "$worktree_gitignore"
      return 0
      ;;
    no)
      return 0
      ;;
  esac

  [[ -t 0 ]] || return 0

  local answer=""
  printf 'Add .worktrees/ to .gitignore in this branch? [Y/n] '
  read -r answer
  mkdir -p "$state_dir"
  case "${answer:-Y}" in
    [Yy]*)
      printf '%s\n' yes > "$answer_file"
      printf '%s\n' '.worktrees/' >> "$worktree_gitignore"
      ;;
    *)
      printf '%s\n' no > "$answer_file"
      ;;
  esac
}

_spawn_new() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    _spawn_print_new_usage
    return 0
  fi

  if [[ -z "${1:-}" ]]; then
    _spawn_print_new_usage
    return 1
  fi

  _spawn_parse_session_args new "$@" || { _spawn_clear_session_args; return 1; }

  local branch="$_SPAWN_SESSION_BRANCH"
  local prompt="$_SPAWN_SESSION_PROMPT"
  local bypass="$_SPAWN_SESSION_BYPASS"
  local agent="$_SPAWN_SESSION_AGENT"
  local from_ref="$_SPAWN_SESSION_FROM"
  _spawn_clear_session_args

  if [[ -z "$branch" ]]; then
    _spawn_print_new_usage
    return 1
  fi

  local repo_root
  repo_root="$(_spawn_require_repo_root)" || return 1

  local layout
  layout="$(_spawn_get_layout "$repo_root")"

  local start_point
  start_point="$(_spawn_resolve_start_point "$from_ref")" || return 1

  local worktree_dir
  worktree_dir="$(_spawn_worktree_dir "$repo_root" "$branch" "$layout")"

  if [[ -d "$worktree_dir" ]]; then
    cd "$worktree_dir" || return 1
  else
    local base_dir
    base_dir="$(_spawn_worktree_base "$repo_root" "$layout")"

    if [[ "$layout" != "sibling" ]]; then
      mkdir -p "$base_dir"
    fi

    _spawn_git_stdout_quiet -C "$repo_root" worktree add "$worktree_dir" -b "$branch" "$start_point" || return 1
    cd "$worktree_dir" || return 1

    _spawn_run_hook setup "$repo_root" "$worktree_dir" || true
  fi

  _spawn_register_repo "$repo_root"
  _spawn_offer_gitignore "$repo_root" "$worktree_dir" "$layout"
  _spawn_green "✓"; echo " Created worktree: $branch"
  _spawn_dim "  Launching $agent..."; echo ""
  _spawn_schedule_update_check
  _spawn_run_agent "$agent" interactive "$prompt" "$bypass"
}

_spawn_start() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    _spawn_print_start_usage
    return 0
  fi

  if [[ -z "${1:-}" ]]; then
    _spawn_print_start_usage
    return 1
  fi

  _spawn_parse_session_args start "$@" || { _spawn_clear_session_args; return 1; }

  local branch="$_SPAWN_SESSION_BRANCH"
  local prompt="$_SPAWN_SESSION_PROMPT"
  local bypass="$_SPAWN_SESSION_BYPASS"
  local agent="$_SPAWN_SESSION_AGENT"
  _spawn_clear_session_args

  if [[ -z "$branch" ]]; then
    _spawn_print_start_usage
    return 1
  fi

  local repo_root
  repo_root="$(_spawn_require_repo_root)" || return 1

  local worktree_dir
  worktree_dir="$(_spawn_worktree_dir "$repo_root" "$branch")"

  if [[ ! -d "$worktree_dir" ]]; then
    _spawn_error "worktree not found: $worktree_dir"
    echo "Run 'spawn ls' to see available worktrees, or 'spawn new $branch' to create one." >&2
    return 1
  fi

  cd "$worktree_dir" || return 1
  _spawn_green "✓"; echo " Resuming session: $branch"
  _spawn_dim "  Launching $agent..."; echo ""
  _spawn_schedule_update_check
  _spawn_run_agent "$agent" continue "$prompt" "$bypass"
}

_spawn_cd() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    _spawn_print_cd_usage
    return 0
  fi

  local repo_root
  repo_root="$(_spawn_require_repo_root)" || return 1

  if [[ -z "${1:-}" ]]; then
    cd "$repo_root" || return 1
    return 0
  fi

  local branch="$1"
  local worktree_dir
  worktree_dir="$(_spawn_worktree_dir "$repo_root" "$branch")"

  if [[ ! -d "$worktree_dir" ]]; then
    _spawn_error "worktree not found: $worktree_dir"
    echo "Run 'spawn ls' to see available worktrees." >&2
    return 1
  fi

  cd "$worktree_dir" || return 1
}

_spawn_ls() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    _spawn_print_ls_usage
    return 0
  fi

  local repo_root
  repo_root="$(_spawn_require_repo_root)" || return 1
  local repo_parent="${repo_root%/*}"

  local rows="" max_w=6
  local wt_dir="" wt_branch=""
  while IFS=$'\t' read -r wt_dir wt_branch; do
    [[ -n "$wt_dir" ]] || continue
    (( ${#wt_branch} > max_w )) && max_w=${#wt_branch}
    rows+="${wt_branch}"$'\t'"${wt_dir#$repo_parent/}"$'\n'
  done < <(_spawn_spawn_worktree_pairs "$repo_root")

  if [[ -z "$rows" ]]; then
    echo "No spawn worktrees found."
    return 0
  fi

  _spawn_bold "$(printf '%-*s  %s' "$max_w" "BRANCH" "PATH")"
  echo ""
  local _b _p
  while IFS=$'\t' read -r _b _p; do
    [[ -n "$_b" ]] || continue
    printf '%-*s  %s\n' "$max_w" "$_b" "$_p"
  done <<< "$rows"
}

_spawn_merge() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    _spawn_print_merge_usage
    return 0
  fi

  local branch=""
  local squash=false
  local arg

  for arg in "$@"; do
    case "$arg" in
      --squash) squash=true ;;
      *) branch="$arg" ;;
    esac
  done

  local repo_root
  repo_root="$(_spawn_require_repo_root)" || return 1

  local layout
  layout="$(_spawn_get_layout "$repo_root")"

  if [[ -z "$branch" ]]; then
    branch="$(_spawn_detect_worktree_branch "$repo_root" "$layout" 2>/dev/null || true)"
    if [[ -z "$branch" ]]; then
      _spawn_print_merge_usage
      return 1
    fi
  fi

  local worktree_dir
  worktree_dir="$(_spawn_worktree_dir "$repo_root" "$branch" "$layout")"

  if [[ ! -d "$worktree_dir" ]]; then
    _spawn_error "worktree not found: $worktree_dir"
    echo "Run 'spawn ls' to see available worktrees." >&2
    return 1
  fi

  if ! git -C "$worktree_dir" diff --quiet 2>/dev/null || \
     ! git -C "$worktree_dir" diff --cached --quiet 2>/dev/null; then
    _spawn_error "worktree has uncommitted changes: $worktree_dir"
    echo "Commit or stash them before merging." >&2
    return 1
  fi

  local target_branch
  target_branch="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [[ -z "$target_branch" ]]; then
    _spawn_error "could not determine branch in main checkout"
    return 1
  fi

  if [[ "$branch" == "$target_branch" ]]; then
    _spawn_error "cannot merge '$branch' into itself"
    return 1
  fi

  cd "$repo_root" || return 1

  if [[ "$squash" == true ]]; then
    git merge --squash --quiet "$branch" || return 1
    echo "Squash merge ready: $branch -> $target_branch"
  else
    git merge --quiet "$branch" || return 1
    echo "Merged $branch into $target_branch"
  fi
}

_spawn_rm() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    _spawn_print_rm_usage
    return 0
  fi

  local force=false
  local branch=""
  local arg

  for arg in "$@"; do
    case "$arg" in
      --force|-f) force=true ;;
      --all) branch="--all" ;;
      *) branch="$arg" ;;
    esac
  done

  local repo_root
  repo_root="$(_spawn_require_repo_root)" || return 1

  if [[ "$branch" == "--all" ]]; then
    _spawn_rm_all "$repo_root"
    return $?
  fi

  local layout
  layout="$(_spawn_get_layout "$repo_root")"

  if [[ -z "$branch" ]]; then
    branch="$(_spawn_detect_worktree_branch "$repo_root" "$layout" 2>/dev/null || true)"
    if [[ -z "$branch" ]]; then
      _spawn_print_rm_usage
      return 1
    fi
    cd "$repo_root" || return 1
  fi

  local worktree_dir
  worktree_dir="$(_spawn_worktree_dir "$repo_root" "$branch" "$layout")"

  if [[ ! -d "$worktree_dir" ]]; then
    _spawn_error "worktree not found: $worktree_dir"
    return 1
  fi

  local -a remove_args=("$worktree_dir")
  $force && remove_args=("--force" "${remove_args[@]}")

  cd "$worktree_dir" || return 1
  _spawn_run_hook teardown "$repo_root" "$worktree_dir" || true
  cd "$repo_root" || return 1

  if _spawn_git_stdout_quiet -C "$repo_root" worktree remove "${remove_args[@]}"; then
    if git -C "$repo_root" branch -D "$branch" >/dev/null 2>&1; then
      echo "Removed $branch"
    else
      _spawn_error "removed worktree but failed to delete branch: $branch"
      return 1
    fi
  else
    _spawn_error "failed to remove worktree: $branch"
    if ! $force; then
      echo "Hint: use 'spawn rm --force $branch' to remove a worktree with uncommitted changes"
    fi
    return 1
  fi
}

_spawn_rm_all() {
  local repo_root="$1"
  local layout
  layout="$(_spawn_get_layout "$repo_root")"
  local base_dir
  base_dir="$(_spawn_worktree_base "$repo_root" "$layout")"

  if [[ "$layout" != "sibling" && ! -d "$base_dir" ]]; then
    echo "No worktrees directory found."
    return 0
  fi

  local wt_pairs="" wt_dir="" wt_branch=""
  while IFS=$'\t' read -r wt_dir wt_branch; do
    [[ -n "$wt_dir" ]] || continue
    wt_pairs+="${wt_dir}"$'\t'"${wt_branch}"$'\n'
  done < <(_spawn_spawn_worktree_pairs "$repo_root" "$layout")

  if [[ -z "$wt_pairs" ]]; then
    echo "No spawn worktrees to remove."
    return 0
  fi

  local count=0
  echo "This will remove ALL spawn worktrees and their branches:"
  echo ""
  while IFS=$'\t' read -r wt_dir wt_branch; do
    [[ -n "$wt_dir" ]] || continue
    echo "  ${wt_dir#$repo_root/}  (branch: $wt_branch)"
    count=$((count + 1))
  done <<< "$wt_pairs"
  echo ""

  local expected="DELETE $count WORKTREES"
  if [[ ! -t 0 ]]; then
    echo "Refusing to remove all worktrees without an interactive terminal."
    echo "Re-run 'spawn rm --all' from a TTY and type: $expected"
    return 1
  fi
  printf 'Type "%s" to confirm: ' "$expected"
  read -r confirmation
  if [[ "$confirmation" != "$expected" ]]; then
    echo "Aborted."
    return 1
  fi

  if _spawn_detect_worktree_branch "$repo_root" >/dev/null 2>&1; then
    cd "$repo_root" || return 1
  fi

  echo ""
  local failed=0
  while IFS=$'\t' read -r wt_dir wt_branch; do
    [[ -n "$wt_dir" ]] || continue
    cd "$wt_dir" 2>/dev/null || { ((failed++)); continue; }
    _spawn_run_hook teardown "$repo_root" "$wt_dir" || true
    if _spawn_git_stdout_quiet -C "$repo_root" worktree remove --force "$wt_dir" 2>/dev/null; then
      if git -C "$repo_root" branch -D "$wt_branch" >/dev/null 2>&1; then
        echo "  removed $wt_branch"
      else
        echo "  failed $wt_branch"
        ((failed++))
      fi
    else
      echo "  failed $wt_branch"
      ((failed++))
    fi
  done <<< "$wt_pairs"

  cd "$repo_root" || true

  echo ""
  if [[ "$failed" -eq 0 ]]; then
    echo "Removed $count worktree(s)"
  else
    echo "Removed $((count - failed))/$count worktree(s); $failed failed."
  fi
}

_spawn_init() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    _spawn_print_init_usage
    return 0
  fi

  local replace=false
  local agent="$(_spawn_default_agent)"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a|--agent)
        if [[ $# -lt 2 ]]; then
          _spawn_error "missing value for $1"
          return 1
        fi
        agent="$2"
        shift 2
        ;;
      --replace)
        replace=true
        shift
        ;;
      *)
        _spawn_error "unknown option: $1"
        return 1
        ;;
    esac
  done

  local repo_root
  repo_root="$(_spawn_require_repo_root)" || return 1
  _spawn_validate_agent "$agent" || return 1

  case "$agent" in
    claude) _spawn_require_claude || return 1 ;;
    codex) _spawn_require_codex || return 1 ;;
  esac

  if [[ ! -t 0 || ! -t 1 ]]; then
    _spawn_error "spawn init requires an interactive terminal"
    return 1
  fi

  local state_dir
  state_dir="$(_spawn_repo_state_dir "$repo_root")" || {
    _spawn_error "could not determine the repository metadata directory"
    return 1
  }

  local setup_file="$state_dir/setup"

  if [[ -f "$setup_file" && "$replace" != true ]]; then
    _spawn_error "setup hook already exists: $setup_file"
    echo "Run 'spawn init --replace' to recreate it." >&2
    return 1
  fi

  mkdir -p "$state_dir"

  local prompt
  IFS= read -r -d '' prompt <<'PROMPT' || true
Inspect this repository and create the spawn setup hook file under the shared Git metadata directory. Work directly in the repo and write the file yourself.

Rules:
- The hook path is: $(git rev-parse --git-common-dir)/spawn/setup
- The file must start with #!/bin/bash
- Set REPO_ROOT="$(dirname "$(git rev-parse --git-common-dir)")"
- Symlink gitignored secret/config files from $REPO_ROOT when relevant
- Install dependencies if a lock file exists and the repo needs them
- Run codegen/build/bootstrap steps only if they actually apply to this repo
- Use short bash comments only where helpful
- No echo statements, no decorative output
- If the repo needs no setup, write a minimal script with a one-line comment explaining that
- After writing the file, make it executable
- Do not ask the user to copy or save files manually; make the change directly
- Briefly explain what you changed once the file is in place
PROMPT

  if [[ "$replace" == true ]]; then
    prompt="$prompt"$'\n'"An existing hook may already be present. Replace it with an updated version if needed."
  fi

  cd "$repo_root" || return 1
  _spawn_run_agent "$agent" interactive "$prompt" ""
}

_spawn_config() {
  local repo_root
  repo_root="$(_spawn_repo_root 2>/dev/null)"

  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    _spawn_print_config_usage
    return 0
  fi

  if [[ -z "${1:-}" ]]; then
    local layout="" source=""
    local repo_config_file=""
    local global_config_file

    if [[ -n "$repo_root" ]]; then
      repo_config_file="$(_spawn_repo_config_file "$repo_root" 2>/dev/null || true)"
    fi
    global_config_file="$(_spawn_global_config_file)"

    if [[ -n "$repo_config_file" ]]; then
      layout="$(_spawn_read_layout_from_file "$repo_config_file")"
      [[ -n "$layout" ]] && source="$repo_config_file"
    fi
    if [[ -z "$layout" ]]; then
      layout="$(_spawn_read_layout_from_file "$global_config_file")"
      [[ -n "$layout" ]] && source="~/.spawn/config.json"
    fi
    if [[ -z "$layout" ]]; then
      layout="nested"
      source="default"
    fi
    echo "layout: $layout"
    echo "source: $source"
    return 0
  fi

  if [[ "${1:-}" != "set" ]]; then
    _spawn_print_config_usage
    return 1
  fi
  shift

  local global=false
  local key="" preset=""
  for arg in "$@"; do
    case "$arg" in
      --help|-h)
        _spawn_print_config_usage
        return 0
        ;;
      --global) global=true ;;
      layout) key="layout" ;;
      *) preset="$arg" ;;
    esac
  done

  if [[ "$key" != "layout" || -z "$preset" ]]; then
    echo "Usage: spawn config set layout <preset> [--global]" >&2
    return 1
  fi

  case "$preset" in
    nested|outer-nested|sibling) ;;
    *)
      _spawn_error "invalid layout: $preset"
      echo "Valid presets: nested, outer-nested, sibling" >&2
      return 1
      ;;
  esac

  local config_file
  if [[ "$global" == true ]]; then
    config_file="$(_spawn_global_config_file)"
  else
    if [[ -z "$repo_root" ]]; then
      _spawn_error "not in a git repo. Use --global to set globally."
      return 1
    fi
    config_file="$(_spawn_repo_config_file "$repo_root")" || {
      _spawn_error "could not determine the repository metadata directory"
      return 1
    }
    mkdir -p "${config_file%/*}"
  fi

  if [[ -n "$repo_root" ]]; then
    local existing=0 _wt_dir _wt_branch
    while IFS=$'\t' read -r _wt_dir _wt_branch; do
      [[ -n "$_wt_dir" ]] && ((existing++))
    done < <(_spawn_spawn_worktree_pairs "$repo_root")
    if [[ "$existing" -gt 0 ]]; then
      echo "Warning: $existing existing worktrees use the current layout."
      echo "Changing layout won't move them. Remove them first with 'spawn rm --all'."
    fi
  fi

  printf '{\n  "layout": "%s"\n}\n' "$preset" > "$config_file"

  local target="per-repo"
  [[ "$global" == true ]] && target="global"
  echo "Set $target layout to $preset"
}

_spawn_register_repo() {
  local repo_root="$1"
  local registry="$SPAWN_HOME/repos"
  mkdir -p "$SPAWN_HOME"
  if [[ -f "$registry" ]]; then
    grep -qxF "$repo_root" "$registry" 2>/dev/null && return 0
  fi
  printf '%s\n' "$repo_root" >> "$registry"
}

_spawn_registered_repos() {
  local registry="$SPAWN_HOME/repos"
  [[ -f "$registry" ]] || return 0
  local clean="" _repo
  while IFS= read -r _repo; do
    [[ -n "$_repo" ]] || continue
    if [[ -d "$_repo" ]] && git -C "$_repo" rev-parse --git-dir >/dev/null 2>&1; then
      printf '%s\n' "$_repo"
      clean+="$_repo"$'\n'
    fi
  done < "$registry"
  printf '%s' "$clean" > "$registry"
}

_spawn_collect_agent_procs() {
  local _seen="" _pid _cmd _cwd _agent _start
  while IFS= read -r _line; do
    [[ -n "$_line" ]] || continue
    _line="${_line#"${_line%%[! ]*}"}"
    _pid="${_line%% *}"
    _cmd="${_line#* }"
    case "$_cmd" in
      *claude*) _agent="claude" ;;
      *codex*)  _agent="codex" ;;
      *)        continue ;;
    esac
    if [[ -d "/proc/$_pid" ]]; then
      _cwd="$(readlink -f "/proc/$_pid/cwd" 2>/dev/null || true)"
    elif command -v lsof >/dev/null 2>&1; then
      _cwd="$(lsof -p "$_pid" 2>/dev/null | awk '$4=="cwd" {print $NF}')"
    else
      continue
    fi
    [[ -n "$_cwd" ]] || continue
    case $'\n'"$_seen" in *$'\n'"$_cwd"$'\n'*) continue ;; esac
    _seen+="${_cwd}"$'\n'
    _start="$(ps -o lstart= -p "$_pid" 2>/dev/null | xargs)" || _start=""
    if [[ -n "$_start" ]]; then
      if date -j -f "%c" "$_start" "+%s" >/dev/null 2>&1; then
        _start="$(date -j -f "%c" "$_start" "+%s")"
      elif date -d "$_start" "+%s" >/dev/null 2>&1; then
        _start="$(date -d "$_start" "+%s")"
      else
        _start=""
      fi
    fi
    printf '%s:%s:%s\n' "$_cwd" "$_agent" "${_start:-0}"
  done < <(ps -eo pid=,command= 2>/dev/null | grep -E '[c]laude|[c]odex')
}

_spawn_elapsed_label() {
  local elapsed=$(( $(date +%s) - $1 ))
  if (( elapsed < 60 )); then printf 'just now'
  elif (( elapsed < 3600 )); then printf '%sm ago' "$(( elapsed / 60 ))"
  elif (( elapsed < 86400 )); then printf '%sh ago' "$(( elapsed / 3600 ))"
  else printf '%sd ago' "$(( elapsed / 86400 ))"
  fi
}

_spawn_match_agent() {
  local wt_dir="$1" procs="$2" _proc_line _proc_cwd _proc_rest _proc_agent _proc_start
  while IFS= read -r _proc_line; do
    [[ -n "$_proc_line" ]] || continue
    _proc_start="${_proc_line##*:}"
    _proc_rest="${_proc_line%:*}"
    _proc_agent="${_proc_rest##*:}"
    _proc_cwd="${_proc_rest%:*}"
    if [[ "$_proc_cwd" == "$wt_dir" || "$_proc_cwd" == "$wt_dir/"* ]]; then
      printf '%s:%s' "$_proc_agent" "$_proc_start"
      return 0
    fi
  done <<< "$procs"
  return 1
}

_spawn_status() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    _spawn_print_status_usage
    return 0
  fi

  local show_all=false
  [[ "${1:-}" == "--all" ]] && show_all=true

  local agent_procs
  agent_procs="$(_spawn_collect_agent_procs)"

  if [[ "$show_all" == true ]]; then
    _spawn_status_all "$agent_procs"
  else
    _spawn_status_repo "$agent_procs"
  fi
}

_spawn_status_repo() {
  local agent_procs="$1"
  local repo_root
  repo_root="$(_spawn_repo_root)" || { _spawn_error "not in a git repo (use --all for global view)"; return 1; }

  local rows="" max_b=6 max_w=8
  local wt_dir="" wt_branch=""

  while IFS=$'\t' read -r wt_dir wt_branch; do
    [[ -d "$wt_dir" ]] || continue

    local match=""
    match="$(_spawn_match_agent "$wt_dir" "$agent_procs")" || true

    local agent="" start_ts="" last_activity="-" display_state="○ idle"
    if [[ -n "$match" ]]; then
      agent="${match%%:*}"
      start_ts="${match#*:}"
      display_state="● active"
      [[ "$start_ts" != "0" && -n "$start_ts" ]] && last_activity="$(_spawn_elapsed_label "$start_ts")"
    fi

    local rel_path="${wt_dir##*/}"
    (( ${#wt_branch} > max_b )) && max_b=${#wt_branch}
    (( ${#rel_path} > max_w )) && max_w=${#rel_path}
    rows+="${wt_branch}"$'\t'"${rel_path}"$'\t'"${agent:--}"$'\t'"${display_state}"$'\t'"${last_activity}"$'\n'
  done < <(_spawn_spawn_worktree_pairs "$repo_root")

  if [[ -z "$rows" ]]; then
    echo "No spawn worktrees found."
    return 0
  fi

  _spawn_bold "$(printf '%-*s  %-*s  %-8s  %-12s  %s' "$max_b" "BRANCH" "$max_w" "WORKTREE" "AGENT" "STATUS" "LAST ACTIVITY")"
  echo ""
  local _b _w _ag _s _a
  while IFS=$'\t' read -r _b _w _ag _s _a; do
    [[ -n "$_b" ]] || continue
    printf '%-*s  %-*s  %-8s  %-12s  %s\n' "$max_b" "$_b" "$max_w" "$_w" "$_ag" "$_s" "$_a"
  done <<< "$rows"
}

_spawn_status_all() {
  local agent_procs="$1"
  local repos
  repos="$(_spawn_registered_repos)"

  if [[ -z "$repos" ]]; then
    echo "No spawn repositories registered yet."
    return 0
  fi

  local rows="" max_b=6 max_w=8 max_r=4
  local _repo repo_name="" wt_dir="" wt_branch=""
  local agent="" last_activity="" rel_path="" display_state=""

  while IFS= read -r _repo; do
    [[ -n "$_repo" ]] || continue
    repo_name="${_repo##*/}"
    while IFS=$'\t' read -r wt_dir wt_branch; do
      [[ -d "$wt_dir" ]] || continue

      local match=""
      match="$(_spawn_match_agent "$wt_dir" "$agent_procs")" || true

      agent="" last_activity="-" display_state="○ idle"
      if [[ -n "$match" ]]; then
        agent="${match%%:*}"
        local start_ts="${match#*:}"
        display_state="● active"
        [[ "$start_ts" != "0" && -n "$start_ts" ]] && last_activity="$(_spawn_elapsed_label "$start_ts")"
      fi

      rel_path="${wt_dir##*/}"
      (( ${#wt_branch} > max_b )) && max_b=${#wt_branch}
      (( ${#rel_path} > max_w )) && max_w=${#rel_path}
      (( ${#repo_name} > max_r )) && max_r=${#repo_name}
      rows+="${repo_name}"$'\t'"${wt_branch}"$'\t'"${rel_path}"$'\t'"${agent:--}"$'\t'"${display_state}"$'\t'"${last_activity}"$'\n'
    done < <(_spawn_spawn_worktree_pairs "$_repo")
  done <<< "$repos"

  if [[ -z "$rows" ]]; then
    echo "No spawn worktrees found across registered repos."
    return 0
  fi

  _spawn_bold "$(printf '%-*s  %-*s  %-*s  %-8s  %-12s  %s' "$max_r" "REPO" "$max_b" "BRANCH" "$max_w" "WORKTREE" "AGENT" "STATUS" "LAST ACTIVITY")"
  echo ""
  local _r _b _w _ag _s _a
  while IFS=$'\t' read -r _r _b _w _ag _s _a; do
    [[ -n "$_r" ]] || continue
    printf '%-*s  %-*s  %-*s  %-8s  %-12s  %s\n' "$max_r" "$_r" "$max_b" "$_b" "$max_w" "$_w" "$_ag" "$_s" "$_a"
  done <<< "$rows"
}

_spawn_update() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    _spawn_print_update_usage
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    _spawn_error "npm not found. Install Node.js 18+ first."
    return 1
  fi

  _spawn_dim "Current: v$SPAWN_VERSION"; echo ""
  echo "Checking for updates..."

  local latest
  latest="$(npm view @jxtools/spawn version 2>/dev/null || true)"

  if [[ -z "$latest" ]]; then
    _spawn_error "could not check latest version"
    return 1
  fi

  if [[ "$latest" == "$SPAWN_VERSION" ]]; then
    _spawn_green "✓"; echo " Already on the latest version (v$SPAWN_VERSION)"
    return 0
  fi

  echo "New version available: v$latest"
  echo "Updating..."

  if npm install -g @jxtools/spawn@latest >/dev/null 2>&1; then
    local global_package_dir
    global_package_dir="$(_spawn_global_package_dir)" || {
      _spawn_error "update failed: could not resolve the global package directory"
      return 1
    }
    SPAWN_VERSION="$(_spawn_package_version_from_dir "$global_package_dir")" || {
      _spawn_error "update failed: installed package is incomplete"
      return 1
    }
    if [[ "$SPAWN_VERSION" != "$latest" ]]; then
      _spawn_error "update failed: expected v$latest, found v$SPAWN_VERSION"
      return 1
    fi
    _spawn_green "✓"; echo " Updated to v$SPAWN_VERSION"
  else
    _spawn_error "update failed"
    return 1
  fi
}

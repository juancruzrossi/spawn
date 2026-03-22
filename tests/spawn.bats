#!/usr/bin/env bats

setup() {
  PROJECT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
}

@test "loader exposes spawn help" {
  run bash -c 'source "$1/spawn.sh" && spawn --help' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "ls succeeds when there are no spawn worktrees" {
  run bash -c '
    source "$1/spawn.sh"
    tmp_dir="$(mktemp -d)"
    _spawn_repo_root() { printf "%s\n" "$tmp_dir"; }
    _spawn_get_layout() { printf "%s\n" nested; }
    _spawn_worktree_base() { printf "%s\n" "$tmp_dir/.worktrees"; }
    git() { return 0; }
    _spawn_ls
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "No spawn worktrees found." ]
}

@test "ls shows branch and path columns" {
  run bash -c '
    source "$1/spawn.sh"
    tmp_dir="$(mktemp -d)"
    _spawn_repo_root() { printf "%s\n" "$tmp_dir"; }
    _spawn_get_layout() { printf "%s\n" nested; }
    _spawn_worktree_base() { printf "%s\n" "$tmp_dir/.worktrees"; }
    git() {
      cat <<'"'"'EOF'"'"
worktree '"$tmp_dir"'/main
HEAD 1111111
branch refs/heads/main

worktree '"$tmp_dir"'/.worktrees/feat-test-1
HEAD 2222222
branch refs/heads/feat/test-1
EOF
    }
    _spawn_ls
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BRANCH"* ]]
  [[ "$output" == *"PATH"* ]]
  [[ "$output" == *"feat/test-1"* ]]
  [[ "$output" == *".worktrees/feat-test-1"* ]]
}

@test "zsh can source the loader without compdef errors" {
  run zsh -c 'source "$1/spawn.sh" && spawn version' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == spawn* ]]
}

@test "new parser normalizes spaced branch names and keeps explicit base ref" {
  run bash -c '
    source "$1/spawn.sh"
    _spawn_parse_session_args new feature one -a codex -b -f develop -p hello
    printf "%s|%s|%s|%s|%s\n" "$_SPAWN_SESSION_BRANCH" "$_SPAWN_SESSION_PROMPT" "$_SPAWN_SESSION_BYPASS" "$_SPAWN_SESSION_AGENT" "$_SPAWN_SESSION_FROM"
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "feature-one|hello|1|codex|develop" ]
}

@test "new defaults to claude when no agent is configured" {
  run bash -c '
    source "$1/spawn.sh"
    unset SPAWN_AGENT
    _spawn_parse_session_args new feature-one
    printf "%s\n" "$_SPAWN_SESSION_AGENT"
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "claude" ]
}

@test "start forwards bypass and continue flags to claude" {
  run bash -c '
    source "$1/spawn.sh"
    tmp_dir="$(mktemp -d)"
    mkdir -p "$tmp_dir/wt"
    _spawn_repo_root() { printf "%s\n" "$tmp_dir"; }
    _spawn_worktree_dir() { printf "%s\n" "$tmp_dir/wt"; }
    _spawn_schedule_update_check() { :; }
    claude() { printf "CLAUDE:%s\n" "$*"; }
    SPAWN_BYPASS=1
    export SPAWN_BYPASS
    _spawn_start feature-x -a claude -p "follow up"
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CLAUDE:--dangerously-skip-permissions -c follow up"* ]]
}

@test "start forwards bypass and resume flags to codex" {
  run bash -c '
    source "$1/spawn.sh"
    tmp_dir="$(mktemp -d)"
    mkdir -p "$tmp_dir/wt"
    _spawn_repo_root() { printf "%s\n" "$tmp_dir"; }
    _spawn_worktree_dir() { printf "%s\n" "$tmp_dir/wt"; }
    _spawn_schedule_update_check() { :; }
    codex() { printf "CODEX:%s\n" "$*"; }
    _spawn_start feature-x -a codex -b -p "follow up"
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CODEX:resume --last --yolo follow up"* ]]
}

@test "new resolves an explicit base ref before creating the worktree" {
  run bash -c '
    source "$1/spawn.sh"
    tmp_dir="$(mktemp -d)"
    args_file="$tmp_dir/git-args"
    mkdir -p "$tmp_dir"
    _spawn_repo_root() { printf "%s\n" "$tmp_dir"; }
    _spawn_worktree_dir() { printf "%s\n" "$tmp_dir/new-wt"; }
    _spawn_worktree_base() { printf "%s\n" "$tmp_dir/.worktrees"; }
    _spawn_get_layout() { printf "%s\n" nested; }
    _spawn_resolve_start_point() { printf "%s\n" "refs/heads/$1"; }
    _spawn_schedule_update_check() { :; }
    git() { printf "%s\n" "$*" > "$args_file"; mkdir -p "$tmp_dir/new-wt"; }
    codex() { printf "CODEX:%s\n" "$*"; }
    _spawn_new feature-x -a codex -f develop -p hello
    printf "\nARGS:%s\n" "$(cat "$args_file")"
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ARGS:-C "*"-b feature-x refs/heads/develop"* ]]
}

@test "new keeps going without a setup hook and launches claude" {
  run bash -c '
    source "$1/spawn.sh"
    tmp_dir="$(mktemp -d)"
    mkdir -p "$tmp_dir"
    _spawn_repo_root() { printf "%s\n" "$tmp_dir"; }
    _spawn_worktree_dir() { printf "%s\n" "$tmp_dir/noninteractive-wt"; }
    _spawn_worktree_base() { printf "%s\n" "$tmp_dir/.worktrees"; }
    _spawn_get_layout() { printf "%s\n" nested; }
    _spawn_resolve_start_point() { printf "%s\n" HEAD; }
    _spawn_schedule_update_check() { :; }
    git() { mkdir -p "$tmp_dir/noninteractive-wt"; return 0; }
    claude() { printf "CLAUDE:%s\n" "$*"; }
    _spawn_new feature-no-setup
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CLAUDE:"* ]]
}

@test "new clears internal session globals after parsing" {
  run bash -c '
    source "$1/spawn.sh"
    tmp_dir="$(mktemp -d)"
    mkdir -p "$tmp_dir"
    _spawn_repo_root() { printf "%s\n" "$tmp_dir"; }
    _spawn_worktree_dir() { printf "%s\n" "$tmp_dir/clean-wt"; }
    _spawn_worktree_base() { printf "%s\n" "$tmp_dir/.worktrees"; }
    _spawn_get_layout() { printf "%s\n" nested; }
    _spawn_resolve_start_point() { printf "%s\n" HEAD; }
    _spawn_schedule_update_check() { :; }
    _spawn_register_repo() { :; }
    _spawn_offer_gitignore() { :; }
    git() { mkdir -p "$tmp_dir/clean-wt"; return 0; }
    claude() { return 0; }
    _spawn_new feature-clean -p hello
    printf "%s|%s\n" "${_SPAWN_SESSION_BRANCH+set}" "${_SPAWN_SESSION_PROMPT+set}"
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "|" ]
}

@test "_spawn_run_hook forwards repo and worktree paths to hooks" {
  run bash -c '
    source "$1/spawn.sh"
    tmp_dir="$(mktemp -d)"
    hook_script="$tmp_dir/setup"
    capture_file="$tmp_dir/capture"
    cat > "$hook_script" <<EOF
#!/bin/sh
printf "%s|%s\n" "\$1" "\$2" > "$capture_file"
EOF
    chmod +x "$hook_script"
    _spawn_repo_hook_file() { printf "%s\n" "$hook_script"; }
    _spawn_run_hook setup "$tmp_dir/repo" "$tmp_dir/wt"
    cat "$capture_file"
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == */repo\|*/wt ]]
}

@test "_spawn_spawn_worktree_pairs returns only spawn-managed worktrees" {
  run bash -c '
    source "$1/spawn.sh"
    tmp_dir="$(mktemp -d)"
    _spawn_get_layout() { printf "%s\n" nested; }
    git() {
      cat <<EOF
worktree $tmp_dir/main
HEAD 1111111
branch refs/heads/main

worktree $tmp_dir/.worktrees/feat-test-1
HEAD 2222222
branch refs/heads/feat/test-1
EOF
    }
    _spawn_spawn_worktree_pairs "$tmp_dir"
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\t'"feat/test-1"* ]]
  [[ "$output" != *$'\t'"main"* ]]
}

@test "init fails fast without an interactive terminal" {
  run bash -c '
    source "$1/spawn.sh"
    _spawn_repo_root() { printf "%s\n" "$PWD"; }
    _spawn_require_claude() { return 0; }
    _spawn_init
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"spawn init requires an interactive terminal"* ]]
}

@test "_spawn_match_agent handles worktree paths with colons" {
  run bash -c '
    source "$1/spawn.sh"
    _spawn_match_agent "/tmp/repo:with:colon" "/tmp/repo:with:colon:codex:123"
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "codex:123" ]
}

@test "postinstall exits non-zero when runtime copy fails" {
  run bash -c '
    project_dir="$1"
    tmp_dir="$(mktemp -d)"
    mkdir -p "$tmp_dir/scripts" "$tmp_dir/home"
    cp "$project_dir/scripts/postinstall.js" "$tmp_dir/scripts/postinstall.js"
    cp "$project_dir/scripts/install-runtime.js" "$tmp_dir/scripts/install-runtime.js"
    cp "$project_dir/package.json" "$tmp_dir/package.json"
    HOME="$tmp_dir/home" SHELL=/bin/bash node "$tmp_dir/scripts/postinstall.js"
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"spawn: failed to copy runtime files:"* ]]
}

@test "install.sh installs runtime into ~/.spawn" {
  run bash -c '
    tmp_home="$(mktemp -d)"
    HOME="$tmp_home" SHELL=/bin/bash sh "$1/install.sh"
    test -f "$tmp_home/.spawn/spawn.sh"
    test -f "$tmp_home/.spawn/VERSION"
    test -d "$tmp_home/.spawn/lib"
    grep -qF ".spawn/spawn.sh" "$tmp_home/.bashrc"
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"spawn installed successfully"* ]]
}

@test "postinstall installs runtime into ~/.spawn" {
  run bash -c '
    tmp_home="$(mktemp -d)"
    HOME="$tmp_home" SHELL=/bin/zsh node "$1/scripts/postinstall.js"
    test -f "$tmp_home/.spawn/spawn.sh"
    test -f "$tmp_home/.spawn/VERSION"
    test -d "$tmp_home/.spawn/lib"
    grep -qF ".spawn/spawn.sh" "$tmp_home/.zshrc"
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed. Restart your shell"* ]]
}

@test "update fails when npm install leaves an incomplete runtime" {
  run bash -c '
    project_dir="$1"
    tmp_dir="$(mktemp -d)"
    home_dir="$(mktemp -d)"
    bindir="$tmp_dir/bin"
    mkdir -p "$bindir" "$home_dir/.spawn"
    cat > "$bindir/npm" <<'"'"'EOF'"'"'
#!/bin/sh
if [ "$1" = "view" ]; then
  printf "9.9.9\n"
  exit 0
fi
if [ "$1" = "install" ]; then
  printf "9.9.9\n" > "$HOME/.spawn/VERSION"
  exit 0
fi
exit 1
EOF
    chmod +x "$bindir/npm"
    export HOME="$home_dir"
    export PATH="$bindir:/usr/bin:/bin"
    source "$project_dir/spawn.sh"
    _spawn_spinner_start() { :; }
    _spawn_spinner_stop() { :; }
    SPAWN_VERSION=1.4.1
    _spawn_update
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"update failed: installed runtime is incomplete"* ]]
}

@test "_spawn_registered_repos persists cleanup even when captured" {
  run bash -c '
    source "$1/spawn.sh"
    tmp_home="$(mktemp -d)"
    export SPAWN_HOME="$tmp_home/.spawn"
    mkdir -p "$SPAWN_HOME"
    valid_repo="$tmp_home/repo"
    mkdir -p "$valid_repo/.git"
    printf "%s\n%s\n" "$valid_repo" "$tmp_home/missing" > "$SPAWN_HOME/repos"
    git() {
      if [[ "$1" == "-C" && "$3" == "rev-parse" ]]; then
        return 0
      fi
      command git "$@"
    }
    _spawn_registered_repos >/dev/null
    cat "$SPAWN_HOME/repos"
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == */repo ]]
  [[ "$output" != *missing* ]]
}

@test "rm deletes the branch even when it is not merged" {
  run bash -c '
    source "$1/spawn.sh"
    tmp_dir="$(mktemp -d)"
    home_dir="$(mktemp -d)"
    bindir="$tmp_dir/bin"
    mkdir -p "$bindir" "$home_dir/.spawn"
    cat > "$bindir/claude" <<'"'"'EOF'"'"'
#!/bin/sh
exit 0
EOF
    chmod +x "$bindir/claude"
    export HOME="$home_dir"
    export PATH="$bindir:/usr/bin:/bin"
    cd "$tmp_dir"
    git init -q
    git config user.name test
    git config user.email test@example.com
    printf "base\n" > file.txt
    git add file.txt
    git commit -qm init
    spawn new feature/test-one >/dev/null
    cd "$tmp_dir"
    printf "change\n" >> .worktrees/feature-test-one/file.txt
    git -C .worktrees/feature-test-one add file.txt
    git -C .worktrees/feature-test-one commit -qm feat
    spawn rm feature/test-one
    git branch --list
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed feature/test-one"* ]]
  [[ "$output" != *"feature/test-one"* ]]
}

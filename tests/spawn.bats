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

@test "version prefers the local checkout package.json over ~/.spawn/VERSION" {
  run bash -c '
    tmp_home="$(mktemp -d)"
    mkdir -p "$tmp_home/.spawn"
    printf "0.0.1\n" > "$tmp_home/.spawn/VERSION"
    HOME="$tmp_home"
    source "$1/spawn.sh"
    spawn version
  ' -- "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == spawn\ v1.3.0* ]]
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

# Review: spawn-new-current-branch

**Date:** 2026-04-04
**Verdict:** PASS

## Completion Score

**4/4 tasks completed**

| Task | Status | Notes |
|------|--------|-------|
| Task 1: Fallback a rama actual en `_spawn_new` | ✓ | Guard eliminado, fallback post-repo-check con `git symbolic-ref`, setea branch + from_ref |
| Task 2: Actualizar usage text | ✓ | `[<branch>]` opcional, nota attached HEAD, ejemplo agregado |
| Task 3: Actualizar README.md | ✓ | Branch marcado como opcional con nota |
| Task 4: Verificación completa | ✓ | 7/7 tests pasan |

## Goal-Backward Verification

### Truth 1: "`spawn new` sin args detecta la rama actual y la usa como branch"

| Level | Status | Evidence |
|-------|--------|----------|
| EXISTS | ✓ | Fallback block at `lib/spawn-commands.sh:60-68` |
| SUBSTANTIVE | ✓ | Uses `git symbolic-ref --quiet --short HEAD`, sets both `branch` and `from_ref` |
| WIRED | ✓ | Integrated in `_spawn_new` after `_spawn_require_repo_root`, parser relaxed at `lib/spawn-core.sh:774` |
| FUNCTIONAL | ✓ | Test 1: detects `master`, attempts checkout (git worktree constraint = expected) |

**Result:** PASS

### Truth 2: "Positional arg has priority over fallback"

| Level | Status | Evidence |
|-------|--------|----------|
| EXISTS | ✓ | Parser at `spawn-core.sh:748-757` still collects branch_words |
| SUBSTANTIVE | ✓ | Fallback only triggers when `$branch` is empty (`spawn-commands.sh:61`) |
| WIRED | ✓ | `_spawn_parse_session_args` runs before fallback |
| FUNCTIONAL | ✓ | Test 3: `spawn new test-branch` creates worktree, exit 0 |

**Result:** PASS

### Truth 3: "Detached HEAD produces 'missing branch name' error"

| Level | Status | Evidence |
|-------|--------|----------|
| EXISTS | ✓ | Error at `spawn-commands.sh:63-65` |
| SUBSTANTIVE | ✓ | `git symbolic-ref` returns empty on detached HEAD, error fires |
| WIRED | ✓ | Error uses existing `_spawn_error` function |
| FUNCTIONAL | ✓ | Test 4: "spawn: missing branch name", exit 1 |

**Result:** PASS

### Truth 4: "Outside repo produces clean error without git stderr"

| Level | Status | Evidence |
|-------|--------|----------|
| EXISTS | ✓ | `_spawn_require_repo_root` at `spawn-commands.sh:58` runs before any git call |
| SUBSTANTIVE | ✓ | Fallback block is after repo check — git never runs outside repo |
| WIRED | ✓ | Error flow: parser → repo check (fails) → return 1 (never reaches fallback) |
| FUNCTIONAL | ✓ | Test 6: "spawn: not in a git repo", exit 1, no git stderr |

**Result:** PASS

### Truth 5: "Help reflects branch as optional"

| Level | Status | Evidence |
|-------|--------|----------|
| EXISTS | ✓ | Usage text at `spawn-core.sh:155` and README at line 69 |
| SUBSTANTIVE | ✓ | Shows `[<branch>]`, mentions "current branch" and "attached HEAD" |
| WIRED | ✓ | `_spawn_print_new_usage` called by `spawn new --help` |
| FUNCTIONAL | ✓ | Test 5: shows `[<branch>]`, exit 0 |

**Result:** PASS

## Issues

### Blocking
- None

### Warnings
- None

### Info
- Tests 1 & 2 show git worktree constraint: can't checkout a branch already used by another worktree. This is expected git behavior, identical to `spawn new -f <branch>`. The detection logic works correctly.

## Code Quality
- No anti-patterns found (TODO, FIXME, placeholders, debug leftovers)
- Changes are minimal and surgical (15 insertions, 8 deletions across 3 files)

# spawn

`spawn` creates and reopens `git worktree` directories so you can work in parallel with Codex or Claude without mixing changes.

## Install

```sh
./install.sh
source ~/.zshrc
```

If you use Bash, reload `~/.bashrc`.

## Daily use

```sh
spawn new feature-auth
spawn new feature-auth -f develop
spawn new fix-calc -a codex
spawn start feature-auth
spawn ls
spawn merge feature-auth
spawn rm feature-auth
```

## Commands

| Command | What it does |
| --- | --- |
| `spawn new <branch> [-a <agent>] [-b] [-f <base-branch>] [-p <prompt>]` | Creates a branch and worktree, then opens the selected agent in an interactive session. |
| `spawn start <branch> [-a <agent>] [-b] [-p <prompt>]` | Reopens an existing worktree and resumes the most recent session for that worktree in the selected agent. |
| `spawn cd [branch]` | Jumps to the selected worktree. With no args, goes to the repo root. |
| `spawn ls` | Lists spawn-managed branches. |
| `spawn merge [branch] [--squash]` | Merges a worktree branch into the primary checkout. |
| `spawn rm [branch] [-f|--force]` | Removes one worktree and its branch. |
| `spawn rm --all` | Removes all spawn-managed worktrees after explicit confirmation. |
| `spawn init [-a <agent>] [--replace]` | Opens the selected agent in an interactive session to create the repo setup hook. |
| `spawn config` | Shows the effective worktree layout. |
| `spawn config set layout <preset> [--global]` | Sets `nested`, `outer-nested`, or `sibling`. |
| `spawn update` | Reinstalls from the local source directory registered by `install.sh`. |
| `spawn version` | Prints the installed version. |

## Agents

- Default agent: `claude`
- `-a claude` forces Claude
- `-a codex` forces Codex
- `export SPAWN_AGENT=codex` changes the default

`-b` or `--bypass` enables the agent-specific bypass flag:

- Claude: `--dangerously-skip-permissions`
- Codex: `--yolo`

`export SPAWN_BYPASS=1` enables bypass by default.

`-p` seeds the first message, but `spawn new` and `spawn start` still open the normal interactive session for the selected agent.

`spawn init` also opens the agent in a normal interactive session. `spawn` never uses the agents in non-interactive mode.

## Base branch

`spawn new` starts from the current `HEAD` by default.

Use `-f` or `--from` to override it:

```sh
spawn new feature-auth -f develop
spawn new hotfix-payments -f release/1.4
```

`-f` means the base branch or ref used to create the new branch.

## Repo metadata

`spawn` does not create `.spawn/` inside your project.

Per-repo metadata lives under the repository Git metadata directory:

- repo config: `$(git rev-parse --git-common-dir)/spawn/config.json`

Global installation and global config live under `~/.spawn/`.

## Layouts

- `nested`: `.worktrees/<branch>/`
- `outer-nested`: `<repo>.worktrees/<branch>/`
- `sibling`: worktrees next to the main checkout

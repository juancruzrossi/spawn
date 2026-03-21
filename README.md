# spawn

CLI tool for running multiple AI coding agents in parallel.

`spawn` wraps `git worktree` so each agent session gets its own isolated working directory and branch. You can create, resume, and clean up sessions from a single command while the main checkout stays untouched.

Supported agents: **Claude Code** and **Codex CLI**.

## Install

```bash
npm install -g @jxtools/spawn
```

Restart your shell after installing, or run:

```bash
source ~/.zshrc   # or source ~/.bashrc
```

### Requirements

- **Node.js 18+** (for npm installation)
- **Git** (required)
- **AI Provider** (at least one):
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (default)
  - [Codex](https://github.com/openai/codex)

## Update

```bash
npm install -g @jxtools/spawn@latest
```

## Workflow

Start a feature in its own worktree:

```sh
spawn new feature/db-indexes -p "Add missing indexes to the orders table"
```

An urgent fix lands while the feature is still in progress — no need to stash or switch branches:

```sh
spawn new fix/csv-encoding -p "Fix UTF-8 encoding in CSV export for special characters"
```

Once the fix is ready, fold it back and clean up:

```sh
spawn merge fix/csv-encoding --squash
spawn rm fix/csv-encoding
```

Resume the feature the next day, right where the agent left off:

```sh
spawn start feature/db-indexes
```

**`new`** = new worktree, new session. **`start`** = existing worktree, resume session.

## Commands

| Command | What it does |
| --- | --- |
| `spawn new <branch>` | Creates a branch and worktree, then opens the agent. |
| `spawn start <branch>` | Reopens an existing worktree and resumes the session. |
| `spawn cd [branch]` | Jumps to a worktree. No args goes to repo root. |
| `spawn ls` | Lists spawn-managed branches. |
| `spawn merge [branch]` | Merges a worktree branch into the primary checkout. |
| `spawn rm [branch]` | Removes a worktree and its branch. |
| `spawn rm --all` | Removes all spawn worktrees after confirmation. |
| `spawn init` | Generates a setup script that runs automatically on each new worktree (install deps, link secrets, etc.). |
| `spawn config set layout <preset>` | Sets `nested`, `outer-nested`, or `sibling`. |
| `spawn update` | Reinstalls from the local source directory. |
| `spawn version` | Prints the installed version. |

## Flags

| Flag | Used in | Description |
| --- | --- | --- |
| `-a`, `--agent <name>` | `new`, `start`, `init` | Selects the agent (`claude` or `codex`). Defaults to `claude`. |
| `-b`, `--bypass` | `new`, `start` | Enables permissive mode (`--dangerously-skip-permissions` / `--yolo`). |
| `-p`, `--prompt <text>` | `new`, `start` | Seeds the first message. Quote if it contains spaces. |
| `-f`, `--from <ref>` | `new` | Base branch to create from. Defaults to `HEAD`. |
| `-f`, `--force` | `rm` | Force-removes a worktree with uncommitted changes. |
| `--all` | `rm` | Removes all spawn worktrees (interactive confirmation). |
| `--squash` | `merge` | Squash-merges instead of a regular merge. |
| `--replace` | `init` | Overwrites an existing setup hook. |
| `--global` | `config set` | Applies the layout globally instead of per-repo. |

## Environment variables

| Variable | Effect |
| --- | --- |
| `SPAWN_AGENT=codex` | Changes the default agent. |
| `SPAWN_BYPASS=1` | Enables bypass mode by default. |

## License

ISC

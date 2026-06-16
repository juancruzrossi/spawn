# spawn

CLI tool for working on multiple features at the same time in the same repo — each in its own git worktree with its own AI agent. Create, resume, merge, and clean up parallel sessions from a single command.

Supported agents:
- Claude Code
- Codex

## Install

```bash
npm install -g @jxtools/spawn
```

If your environment requires an explicit npm registry:

```bash
npm install -g @jxtools/spawn --registry https://registry.npmjs.org/
```

### Requirements

- **Node.js 18+**
- **Git**
- **AI Provider** (at least one):
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (default)
  - [Codex](https://github.com/openai/codex)

## Update

```bash
spawn update
```

## Workflow

Start a feature in its own worktree:

```sh
spawn new feature/db-indexes -b -p "Add missing indexes to the orders table"
```

An urgent fix lands while the feature is still in progress — no need to stash or switch branches:

```sh
spawn new fix/csv-encoding -b -p "Fix UTF-8 encoding in CSV export for special characters"
```

Once the fix is ready, fold it back and clean up:

```sh
spawn merge fix/csv-encoding --squash
spawn rm fix/csv-encoding --force
```

> `spawn rm` refuses to delete a branch whose commits aren't merged into the
> primary checkout, so it can't silently discard work. A squash merge leaves
> the branch looking unmerged to Git, so pair it with `--force` to remove it.

Resume the feature the next day, right where the agent left off:

```sh
spawn start feature/db-indexes -b
```

**`new`** = new worktree, new session.\
**`start`** = existing worktree, resume session.

## Commands

| Command | What it does |
| --- | --- |
| `spawn new [branch]` | Creates a branch and worktree, then opens the agent. Without a branch, uses the current branch. |
| `spawn start <branch>` | Reopens an existing worktree and resumes the session. |
| `spawn status` | Shows worktree states and active agent sessions. |
| `spawn ls` | Lists spawn-managed branches. |
| `spawn cd [branch]` | Jumps to a worktree. No args goes to repo root. |
| `spawn merge [branch]` | Merges a worktree branch into the primary checkout. |
| `spawn rm [branch]` | Removes a worktree and its branch. |
| `spawn init` | Generates a setup script that runs automatically on each new worktree (install deps, link secrets, etc.). |
| `spawn config set layout <preset>` | Sets `nested`, `outer-nested`, or `sibling`. |
| `spawn update` | Checks for a newer version on npm and updates. |
| `spawn version` | Prints the installed version. |

## Flags

| Flag | Used in | Description |
| --- | --- | --- |
| `-a`, `--agent <name>` | `new`, `start`, `init` | Selects the agent (`claude` or `codex`). Defaults to `claude`. |
| `-b`, `--bypass` | `new`, `start` | Enables permissive mode (`--dangerously-skip-permissions` / `--yolo`). |
| `-p`, `--prompt <text>` | `new`, `start` | Seeds the first message. Quote if it contains spaces. |
| `-f`, `--from <ref>` | `new` | Base branch to create from. Defaults to `HEAD`. |
| `-f`, `--force` | `rm` | Force-removes a worktree with uncommitted changes. |
| `--all` | `rm`, `status` | In `rm`: removes all worktrees. In `status`: shows worktrees across all repos. |
| `--squash` | `merge` | Squash-merges instead of a regular merge. |
| `--replace` | `init` | Overwrites an existing setup hook. |
| `--global` | `config set` | Applies the layout globally instead of per-repo. |

## Worktree layouts

Control where worktrees are created with `spawn config set layout <preset>`.

### `nested` (default)

Worktrees live inside the repo under `.worktrees/`:

```
myapp/
  .worktrees/
    feature-auth/
    fix-csv/
  src/
  package.json
```

```sh
spawn config set layout nested
```

### `outer-nested`

Worktrees live in a sibling directory named `<repo>.worktrees/`:

```
projects/
  myapp/
  myapp.worktrees/
    feature-auth/
    fix-csv/
```

```sh
spawn config set layout outer-nested
```

### `sibling`

Each worktree is a sibling directory named `<repo>-<branch>`:

```
projects/
  myapp/
  myapp-feature-auth/
  myapp-fix-csv/
```

```sh
spawn config set layout sibling
```

### Global vs per-repo

By default the layout is set per-repo. Use `--global` to apply it to all repos:

```sh
spawn config set layout outer-nested --global
```

Per-repo settings take precedence over the global default.

> With `outer-nested` and `sibling` layouts, `spawn ls`, `spawn rm`, `spawn cd`, and `spawn status` work from the parent directory — no need to be inside the repo.

## Environment variables

| Variable | Effect |
| --- | --- |
| `SPAWN_AGENT=codex` | Changes the default agent. |
| `SPAWN_BYPASS=1` | Enables bypass mode by default. |

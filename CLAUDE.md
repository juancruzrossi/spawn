# Project Agent Context

This repository contains `spawn`, a Bash tool for managing `git worktree` directories for parallel Codex or Claude sessions.

## Core facts

- `spawn.sh` is a loader, not the full runtime.
- Shared runtime code lives in `lib/`.
- `install.sh` installs from the current local directory into `~/.spawn/`.
- `spawn update` checks npm for a newer version and self-updates via `npm install -g`.
- `spawn new` and `spawn start` support `claude` and `codex`, with `codex` as the default agent.
- `-p` seeds the first interactive message; it does not switch `new` or `start` into non-interactive execution.
- Missing setup hooks should not block `spawn new`; users can run `spawn init` manually later.
- `spawn init` must also launch the selected agent in interactive CLI mode; no spawn command should use agent batch/exec mode.
- Per-repo metadata lives under `$(git rev-parse --git-common-dir)/spawn/`.

## Command model

- Public entrypoint: `spawn()`.
- Internal functions are prefixed with `_spawn_`.
- Main user commands: `new`, `start`, `cd`, `ls`, `merge`, `rm`, `init`, `config`, `update`, `version`.

## Behavioral expectations

- Preserve command semantics unless a change is explicitly requested.
- Keep setup and teardown hooks under the repo metadata directory, not in the working tree.
- Keep branch-to-directory sanitization intact: `feature/foo` becomes `feature-foo`.
- Keep no-arg detection for `spawn merge` and `spawn rm`.
- Keep the runtime split across `spawn.sh` and `lib/`; do not collapse it back into a monolith.
- Avoid adding dependencies unless they are clearly justified.

## Files that matter

- `spawn.sh`
- `lib/spawn-core.sh`
- `lib/spawn-commands.sh`
- `lib/spawn-completion.sh`
- `install.sh`
- `README.md`

## Versioning

Bump `version` in `package.json` before each PR. Without a version bump, changes won't reach users via `spawn update`. Agree on the new version number with the user.

## Verification

Before considering changes done, source the script in a shell and exercise the affected commands:

```bash
bash -c 'source /path/to/spawn.sh && spawn --help'
```

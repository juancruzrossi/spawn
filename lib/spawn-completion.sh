_spawn_worktree_names() {
  local all_roots
  all_roots="$(_spawn_resolve_all_repo_roots 2>/dev/null)" || return

  local repo_root wt_dir wt_branch
  while IFS= read -r repo_root; do
    [[ -n "$repo_root" ]] || continue
    while IFS=$'\t' read -r wt_dir wt_branch; do
      [[ -n "$wt_dir" ]] && printf '%s\n' "$wt_branch"
    done < <(_spawn_spawn_worktree_pairs "$repo_root")
  done <<< "$all_roots"
}

_spawn_branch_names() {
  local repo_root
  repo_root="$(_spawn_repo_root 2>/dev/null)" || return
  git -C "$repo_root" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null
}

if [[ -n "${ZSH_VERSION:-}" ]]; then
  _spawn_zsh_complete() {
    local cur prev subcmd
    cur="${words[CURRENT]}"
    prev="${words[CURRENT-1]}"
    subcmd="${words[2]}"

    local -a subcmds=(
      'new:Create a worktree and open an agent'
      'start:Reopen an existing worktree'
      'status:Show worktree states and active agents'
      'ls:List spawn-managed worktrees'
      'cd:Jump to a worktree or the repo root'
      'config:Show or change configuration'
      'merge:Merge a worktree branch'
      'rm:Remove one or more worktrees'
      'init:Open an agent to create the setup hook'
      'update:Check npm for updates and self-update'
      'version:Print the installed version'
    )
    local -a agents=(codex claude)

    if (( CURRENT == 2 )); then
      _describe -V 'spawn command' subcmds
      return
    fi

    case "$prev" in
      -a|--agent)
        compadd -- "${agents[@]}"
        return
        ;;
      -f|--from)
        local -a branches=( ${(f)"$(_spawn_branch_names)"} )
        compadd -- "${branches[@]}"
        return
        ;;
    esac

    case "$subcmd" in
      new)
        if [[ "$cur" == -* || -z "$cur" ]]; then
          compadd -- -a --agent -b --bypass -f --from -p --prompt --help
        fi
        ;;
      start)
        if [[ "$cur" == -* ]]; then
          compadd -- -a --agent -b --bypass -p --prompt --help
        else
          local -a worktrees=( ${(f)"$(_spawn_worktree_names)"} )
          compadd -- "${worktrees[@]}"
        fi
        ;;
      cd)
        if [[ "$cur" == -* ]]; then
          compadd -- --help
        else
          local -a worktrees=( ${(f)"$(_spawn_worktree_names)"} )
          compadd -- "${worktrees[@]}"
        fi
        ;;
      ls)
        [[ "$cur" == -* ]] && compadd -- --help
        ;;
      merge)
        if [[ "$cur" == -* ]]; then
          compadd -- --squash --help
        else
          local -a worktrees=( ${(f)"$(_spawn_worktree_names)"} )
          compadd -- "${worktrees[@]}"
        fi
        ;;
      rm)
        if [[ "$cur" == -* ]]; then
          compadd -- --all -f --force --help
        else
          local -a worktrees=( ${(f)"$(_spawn_worktree_names)"} )
          compadd -- "${worktrees[@]}"
        fi
        ;;
      init)
        if [[ "$cur" == -* || -z "$cur" ]]; then
          compadd -- -a --agent --replace --help
        fi
        ;;
      config)
        if (( CURRENT == 3 )); then
          compadd -- set --help
        elif (( CURRENT == 4 )) && [[ "${words[3]}" == "set" ]]; then
          compadd -- layout
        elif (( CURRENT == 5 )) && [[ "${words[3]}" == "set" && "${words[4]}" == "layout" ]]; then
          compadd -- nested outer-nested sibling
        elif (( CURRENT == 6 )) && [[ "${words[3]}" == "set" && "${words[4]}" == "layout" ]]; then
          compadd -- --global
        elif [[ "$cur" == -* ]]; then
          compadd -- --help
        fi
        ;;
      status)
        [[ "$cur" == -* ]] && compadd -- --all --help
        ;;
      update|version)
        [[ "$cur" == -* ]] && compadd -- --help
        ;;
    esac
  }

  if command -v compdef >/dev/null 2>&1; then
    compdef _spawn_zsh_complete spawn
  fi
elif [[ -n "${BASH_VERSION:-}" ]]; then
  _spawn_bash_complete() {
    local cur prev subcmd
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    subcmd="${COMP_WORDS[1]}"

    if (( COMP_CWORD == 1 )); then
      COMPREPLY=( $(compgen -W "new start status ls cd config merge rm init update version" -- "$cur") )
      return
    fi

    case "$prev" in
      -a|--agent)
        COMPREPLY=( $(compgen -W "codex claude" -- "$cur") )
        return
        ;;
      -f|--from)
        COMPREPLY=( $(compgen -W "$(_spawn_branch_names)" -- "$cur") )
        return
        ;;
    esac

    case "$subcmd" in
      new)
        COMPREPLY=( $(compgen -W "-a --agent -b --bypass -f --from -p --prompt --help" -- "$cur") )
        ;;
      start)
        if [[ "$cur" == -* ]]; then
          COMPREPLY=( $(compgen -W "-a --agent -b --bypass -p --prompt --help" -- "$cur") )
        else
          COMPREPLY=( $(compgen -W "$(_spawn_worktree_names)" -- "$cur") )
        fi
        ;;
      cd)
        if [[ "$cur" == -* ]]; then
          COMPREPLY=( $(compgen -W "--help" -- "$cur") )
        else
          COMPREPLY=( $(compgen -W "$(_spawn_worktree_names)" -- "$cur") )
        fi
        ;;
      ls)
        COMPREPLY=( $(compgen -W "--help" -- "$cur") )
        ;;
      merge)
        if [[ "$cur" == -* ]]; then
          COMPREPLY=( $(compgen -W "--squash --help" -- "$cur") )
        else
          COMPREPLY=( $(compgen -W "$(_spawn_worktree_names)" -- "$cur") )
        fi
        ;;
      rm)
        if [[ "$cur" == -* ]]; then
          COMPREPLY=( $(compgen -W "--all -f --force --help" -- "$cur") )
        else
          COMPREPLY=( $(compgen -W "$(_spawn_worktree_names)" -- "$cur") )
        fi
        ;;
      init)
        COMPREPLY=( $(compgen -W "-a --agent --replace --help" -- "$cur") )
        ;;
      config)
        if (( COMP_CWORD == 2 )); then
          COMPREPLY=( $(compgen -W "set --help" -- "$cur") )
        elif (( COMP_CWORD == 3 )) && [[ "${COMP_WORDS[2]}" == "set" ]]; then
          COMPREPLY=( $(compgen -W "layout" -- "$cur") )
        elif (( COMP_CWORD == 4 )) && [[ "${COMP_WORDS[2]}" == "set" && "${COMP_WORDS[3]}" == "layout" ]]; then
          COMPREPLY=( $(compgen -W "nested outer-nested sibling" -- "$cur") )
        elif (( COMP_CWORD == 5 )) && [[ "${COMP_WORDS[2]}" == "set" && "${COMP_WORDS[3]}" == "layout" ]]; then
          COMPREPLY=( $(compgen -W "--global" -- "$cur") )
        else
          COMPREPLY=( $(compgen -W "--help" -- "$cur") )
        fi
        ;;
      status)
        COMPREPLY=( $(compgen -W "--all --help" -- "$cur") )
        ;;
      update|version)
        COMPREPLY=( $(compgen -W "--help" -- "$cur") )
        ;;
      *)
        COMPREPLY=()
        ;;
    esac
  }

  complete -F _spawn_bash_complete spawn
fi

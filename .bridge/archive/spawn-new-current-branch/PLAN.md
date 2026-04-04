# Plan: spawn-new-current-branch

## Overview
Hacer que `spawn new` sin argumento posicional detecte la rama actual y la use como branch, equivalente a `spawn new -f <rama-actual>`. El fallback vive en `_spawn_new` después de validar el repo (no en el parser) para evitar errores de git fuera de un repo.

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/spawn-commands.sh` | Modify | Reemplazar guardia no-args por fallback a rama actual en `_spawn_new` (L48-51 → fallback post-repo-check) |
| `lib/spawn-core.sh` | Modify | Actualizar usage text en `_spawn_print_new_usage` (L153-179) |
| `README.md` | Modify | Actualizar docs de `spawn new` para reflejar branch opcional |

## Tasks

| # | Task | Depends on | Wave | Estimate |
|---|------|-----------|------|----------|
| 1 | Fallback a rama actual en `_spawn_new` | — | 1 | S |
| 2 | Actualizar usage text | — | 1 | S |
| 3 | Actualizar README.md | — | 1 | S |
| 4 | Verificación completa | 1, 2, 3 | 2 | S |

### Task details

#### Task 1: Fallback a rama actual en `_spawn_new`
- **What**: En `lib/spawn-commands.sh`, reemplazar el bloque L48-51 (guardia que muestra usage cuando `$1` está vacío). El nuevo flujo:
  1. Eliminar la guardia `if [[ -z "${1:-}" ]]`.
  2. Dejar que `_spawn_parse_session_args` corra normalmente (si no hay branch, `_SPAWN_SESSION_BRANCH` queda vacío y la función retorna error "missing branch name").
  3. Después de `_spawn_parse_session_args` y después de `_spawn_require_repo_root` (L62-63), agregar: si `$branch` está vacío, hacer `branch="$(git symbolic-ref --quiet --short HEAD)"` y setear `from_ref` al mismo valor. Si sigue vacío (detached HEAD), error "missing branch name".
  4. Ajustar la validación: la línea L772-774 de spawn-core.sh ya no es el único guard — el check de branch vacío ahora vive también en `_spawn_new`.
- **Why**: Mover el fallback *después* de `_spawn_require_repo_root` evita que `git symbolic-ref` corra fuera de un repo y ensucie stderr. Usar `git symbolic-ref --quiet --short HEAD` en vez de `git branch --show-current` da compatibilidad con Git < 2.22.
- **Files**: `lib/spawn-commands.sh`, `lib/spawn-core.sh` (relajar validación de branch vacío en parser para mode=new)
- **Acceptance**: `spawn new` sin args (en `feature/auth`, dentro de un repo) → branch=`feature/auth`, from_ref=`feature/auth`, checkout_existing=true. Fuera de repo → error limpio de `_spawn_require_repo_root`, sin stderr de git. Detached HEAD → error "missing branch name".

#### Task 2: Actualizar usage text
- **What**: En `_spawn_print_new_usage` (spawn-core.sh L152-179):
  - Cambiar `spawn new <branch>` → `spawn new [<branch>]`
  - En Description agregar: "If no branch is given, uses the current branch (requires an attached HEAD)."
  - Agregar ejemplo: `spawn new                                    # uses current branch`
- **Why**: El help debe reflejar que branch es opcional y aclarar el caso detached HEAD.
- **Files**: `lib/spawn-core.sh` (L152-179)
- **Acceptance**: `spawn new --help` muestra `[<branch>]`, menciona "current branch" y "attached HEAD".

#### Task 3: Actualizar README.md
- **What**: En README.md, actualizar la documentación de `spawn new`:
  - Donde dice `spawn new <branch>`, cambiar a `spawn new [<branch>]`
  - Agregar nota de que sin branch usa la rama actual
- **Why**: Mantener docs públicas consistentes con el help.
- **Files**: `README.md`
- **Acceptance**: README refleja branch como opcional.

#### Task 4: Verificación completa
- **What**: Ejecutar estos casos exactos y verificar exit code + output:
  1. `spawn new` sin args en branch `feature/test` → crea worktree, exit 0
  2. `spawn new -p "algo"` sin branch → usa rama actual, exit 0
  3. `spawn new mi-branch` → crea worktree para `mi-branch`, exit 0 (comportamiento existente)
  4. `spawn new` en detached HEAD → stderr "missing branch name", exit 1
  5. `spawn new --help` → muestra help con `[<branch>]`, exit 0
  6. `spawn new -f develop` → funciona igual que antes, exit 0
  7. `spawn start` → sin cambios de comportamiento
- **Why**: Cubrir happy paths + regresiones.
- **Files**: ninguno
- **Acceptance**: Todos los 7 casos pasan con exit code y output esperados.

## Waves

- **Wave 1**: Tasks [1, 2, 3] — sin dependencias entre sí, pueden ejecutarse en paralelo
- **Wave 2**: Task [4] — verificación, depende de Wave 1

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| Fallback no setea `from_ref` → `checkout_existing=false` → falla al crear branch existente | M | M | Task 1 setea ambos: branch y from_ref al mismo valor |
| `git symbolic-ref` falla silenciosamente en edge cases | L | L | `--quiet` suprime errores; vacío → "missing branch name" |

## Acceptance Criteria

- [ ] `spawn new` sin argumentos (en `feature/auth`) crea worktree para `feature/auth`
- [ ] `spawn new -p "algo"` (sin branch) usa la rama actual
- [ ] `spawn new mi-branch` sigue funcionando igual
- [ ] Detached HEAD + `spawn new` sin args → error "missing branch name"
- [ ] `spawn new --help` muestra branch como opcional
- [ ] `spawn new` fuera de repo → error limpio sin stderr de git
- [ ] README actualizado

## Adversarial Review

### Issues found
1. **CRITICAL (Codex)**: Fallback en parser corre `git` antes de validar repo → stderr sucio fuera de un repo.
2. **WARNING (Codex)**: `git branch --show-current` requiere Git ≥ 2.22.
3. **WARNING (Codex)**: Task 4 original solo cubría happy paths.
4. **WARNING (Codex)**: README quedaría inconsistente sin actualización.

### Adjustments made
1. Fallback movido de `_spawn_parse_session_args` a `_spawn_new`, después de `_spawn_require_repo_root`.
2. Usar `git symbolic-ref --quiet --short HEAD` en vez de `git branch --show-current`.
3. Task 4 expandida con 7 casos incluyendo regresiones.
4. Agregada Task 3 para actualizar README.md.

## Codex Review
Codex review aplicado completamente. Cambios principales: reubicación del fallback post-repo-check, `git symbolic-ref` por compatibilidad, verificación expandida, README incluido.

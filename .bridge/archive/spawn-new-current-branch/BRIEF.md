# spawn-new-current-branch

**Git:** yes

## Problem
`spawn new` sin argumentos falla con "missing branch name", obligando al usuario a escribir `spawn new -f feature/auth` cuando ya está parado en `feature/auth`. El comportamiento natural sería que detecte la rama actual automáticamente.

## Decisions
- Decision: Cuando `spawn new` no recibe argumento posicional (branch) ni `-f`, usar `git branch --show-current` como branch, equivalente a pasar `-f <rama-actual>`
- Decision: No bloquear si la rama actual es `main` u otra rama principal — eso es responsabilidad del usuario
- Decision: Si está en detached HEAD (`git branch --show-current` vacío), mantener el error existente "missing branch name"
- Decision: Si se pasa un argumento posicional, ese tiene prioridad (comportamiento actual sin cambios)

## Constraints
- El cambio vive en `_spawn_parse_session_args` en `lib/spawn-core.sh`, solo para `mode == "new"`
- No afecta `spawn start` ni otros comandos
- Debe respetar la lógica existente de `-f` (from_ref) y el join de branch_words con `-`

## Edge Cases
- Detached HEAD: `git branch --show-current` devuelve vacío → error "missing branch name" (comportamiento actual)
- Rama con `/`: `feature/auth` → se sanitiza a `feature-auth` para el directorio (lógica existente no se toca)
- `spawn new -b -p "algo"`: solo flags, sin branch → usa rama actual

## Non-goals
- No cambiar el comportamiento de `spawn start`
- No agregar validación de "estás en main"
- No cambiar el mensaje de error para detached HEAD

## Decision Boundaries
- El agente puede decidir la ubicación exacta del fallback dentro de `_spawn_parse_session_args`
- Cualquier cambio fuera de `lib/spawn-core.sh` y `lib/spawn-commands.sh` requiere aprobación

## Out-of-scope
- Nada identificado

## Acceptance Criteria
1. `spawn new` sin argumentos (estando en `feature/auth`) crea worktree para `feature/auth`, exactamente como `spawn new -f feature/auth`
2. `spawn new -p "algo"` (sin branch) usa la rama actual
3. `spawn new mi-branch` sigue funcionando igual (argumento posicional tiene prioridad)
4. Detached HEAD + `spawn new` sin args → error "missing branch name"

## Open Items
- Ninguno

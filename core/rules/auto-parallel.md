# Auto-Parallel Dispatch

## Rule

Before executing any request with 2+ independent steps, DECOMPOSE into parallel agents. This is not opt-in, it's the default execution mode.

## Quick checklist (run mentally on EVERY request)

1. Does the request have multiple steps? If not, execute directly.
2. Are the steps independent (no shared state, no output dependency)? If not, execute sequentially.
3. If yes: identify independent units, select agent type for each, dispatch ALL in a single message (parallel).

## Agent type selection

| Task pattern | Agent type |
|---|---|
| Research/codebase exploration | `Explore` |
| Code implementation | `general-purpose` or specialized |
| Code review | `code-reviewer`, `multi-perspective-analyzer` |
| Debugging | `systematic-debugger` |
| UI/Frontend | `frontend-ux-specialist`, `ui-layout-architect` |
| Database | `database-performance-optimizer` |
| Planning | `Plan` |
| Vault ops (read/search) | `general-purpose` with vault context |
| Web research | `general-purpose` with WebSearch instructions |
| Simple grep/glob | DO NOT use agent, use tool directly |

## Token efficiency

- `run_in_background: true` when the result is not needed immediately
- `model: "haiku"` for simple lookups
- `model: "sonnet"` for medium complexity
- Opus (default) for complex reasoning
- Write intermediate results to files, not via context messages (saves tokens)

## Anti-patterns

- Running step 1, waiting, step 2, waiting, step 3 -> Dispatch all at once
- Using `general-purpose` for everything -> Match agent type to task
- Vague prompt "handle X" -> Complete context + constraints + output format
- Agents editing the same file -> Keep in the same agent
- Micro-splitting a simple task -> Only parallelize when there's real independence
- Spawning an agent for a grep -> Use the Grep tool directly

## Soft cap: max 8 subagents per session

Soft limit of 8 subagents dispatched per session. After 8:

1. **Stop and evaluate**: is the task too large for one session?
2. **If yes**: suggest a new session (see `session-discipline.md`)
3. **If not**: proceed but log `[subagent-cap: N/8, justification]`

The cap exists because each subagent inherits context from the parent session. With 10+ subagents, the multiplied context cost exceeds the benefit of parallelization.

## When NOT to parallelize

- Single atomic task
- All steps are sequential dependencies
- Steps would edit the same files
- Dispatch overhead > time saved (e.g., 2 simple greps)

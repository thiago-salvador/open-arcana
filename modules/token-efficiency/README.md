# Token Efficiency Module

14 rules for minimizing token waste in Claude Code sessions. Based on empirical analysis of how Claude Code handles context windows, compaction, caching, and tool calls.

## The 14 TE Rules

### TE-1: MicroCompact scope
MicroCompact only compresses Bash, FileRead, and Grep results. MCP tool results (Notion, Teams, Gmail, etc.) accumulate uncompressed until AutoCompact triggers. Don't chain 5+ MCP calls without summarizing intermediate results.

### TE-2: Post-compact file restoration
After AutoCompact, the 5 most recently accessed files are restored (5K tokens each, 25K total). Read the most important files last so they survive compaction.

### TE-3: Prompt cache awareness
The system prompt is cached between turns. Editing CLAUDE.md, rules, memory, or tool schemas mid-session breaks the cache and forces full re-tokenization. Avoid unless necessary.

### TE-4: Boot payload minimization
SessionStart hooks should inject pointers, not content. Rules and memory are already loaded via their own mechanisms. Duplicating them in hook output wastes tokens and breaks the prompt cache.

### TE-5: Scratchpad for cross-agent data
When dispatching parallel agents, write findings to files instead of passing them through context messages. Context messages cost tokens for every receiving agent. File reads can be micro-compacted.

### TE-6: Web Search cost awareness
Each WebSearch call costs $0.01 flat. For tasks with 10+ searches, batch queries. Prefer firecrawl over WebSearch for better results at the same cost.

### TE-7: Fast Mode cost awareness
Fast mode costs 6x normal ($30/$150 per MTok vs $5/$25). Same model, just priority inference. For non-urgent tasks, consider if the speed premium is worth it.

### TE-8: Context window math
Default: 200K tokens. With `[1m]` suffix: 1M tokens. AutoCompact triggers at ~80% (configurable). After compact, ~40-60% of context is freed. Do heavy research early, then process after the first compact.

### TE-9: Output discipline
Lead with action or answer. No preamble ("Let me..."), no narration of tool calls, no post-summary ("I've successfully..."), no restating the user's request. One of: action, result, or decision. Not all three.

### TE-10: Targeted reads
Define what you need from a file before reading it. Use offset+limit for known sections. Use grep to locate, then read only the relevant range. Each unnecessary full-file read costs 1-3K tokens.

### TE-11: Tool call consolidation
Batch independent tool calls in a single turn. 3 sequential greps in 3 turns = 3x input context re-read. 3 parallel greps in 1 turn = 1x input context read.

### TE-12: Graduated response length
Match response length to task complexity. Trivial = 1 line. Simple = 2-3 lines. Medium = bullet list. Complex = structured sections. Default shorter, expand only when needed.

### TE-13: Agent prompt efficiency
Give agents the complete task in the initial prompt. Each follow-up message costs a full context re-read. One detailed prompt beats three clarifying messages.

### TE-14: Avoid speculative exploration
Don't read files or search "just in case." Before calling a tool, ask: "Do I need this result to proceed?" If the answer is "maybe," skip it and come back only if blocked.

## Enforcement checklist

At ~50% context window or before compaction:

1. **MCP chain check** -- 5+ MCP calls without summarization? Pause and summarize
2. **File read check** -- 3+ full files read (>200 lines)? Confirm important ones were read last
3. **WebSearch count** -- >10 calls? Evaluate if remaining can be batched
4. **Cache break check** -- CLAUDE.md or rules edited mid-session? Log it

## Files

```
modules/token-efficiency/
  rules/token-efficiency.md  # Full rule definitions (TE-1 through TE-14)
  README.md                  # This file
```

## Installation

Copy `rules/token-efficiency.md` to your project's `.claude/rules/` directory. The rules auto-load on every session.

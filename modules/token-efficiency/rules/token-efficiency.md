# Token Efficiency Rules (based on Claude Code analysis)

## MicroCompact scope (rule TE-1)
MicroCompact only compresses Bash, FileRead, and Grep tool results. MCP tool results (Notion, Teams, Gmail, Smart Connections, Read.AI) are NOT compressed and accumulate in context until AutoCompact triggers. When using multiple MCP sources in one session, process and summarize intermediate results before continuing. Do not chain 5+ MCP calls without summarizing.

## Post-compact file restoration (rule TE-2)
After AutoCompact, the system restores the 5 most recently accessed files (5K tokens each, 25K total). Read the most important files LAST in a session to ensure they survive compaction. Less important reads should come first.

## Prompt cache awareness (rule TE-3)
The system prompt is cached between turns. Any change to CLAUDE.md, rules, memory, or tool schemas breaks the cache and forces full re-tokenization. Avoid editing CLAUDE.md or rules mid-session unless necessary. Each cache break costs the full system prompt in tokens again.

## Boot payload minimization (rule TE-4)
The SessionStart hook should inject pointers, not content. Hot-cache, concept-index, and operating rules are already loaded via rules files and MEMORY.md. Duplicating them in hook output wastes tokens and breaks prompt cache (since hook output changes daily).

## Scratchpad for cross-agent data (rule TE-5)
When dispatching parallel agents, prefer writing findings to files (scratchpad or temp dir) over passing large results through context messages. Context messages cost tokens for every agent that receives them. File reads are cheaper because they can be micro-compacted.

## Web Search cost awareness (rule TE-6)
Each WebSearch call costs $0.01 flat (separate from token costs). In scheduled tasks that do 10+ searches (daily-news, ytai), batch queries when possible. Prefer firecrawl search over WebSearch for better results at the same cost.

## Fast Mode cost awareness (rule TE-7)
Fast mode (default for paying users) costs 6x normal: $30/$150 per MTok vs $5/$25. Same model (Opus 4.6), just priority inference. For non-urgent tasks (vault maintenance, scheduled tasks), consider if the speed premium is worth it.

## Context window math (rule TE-8)
Default: 200K tokens. With [1m] suffix: 1M tokens. AutoCompact triggers at ~80% (configurable via CLAUDE_AUTOCOMPACT_PCT_OVERRIDE, currently set to 75%). After compact, ~40-60% of context is freed. Plan session work accordingly: do the heaviest research/reading early, then process/write after first compact.

## Output discipline (rule TE-9)
Lead with action or answer. Cut these patterns completely:
- No preamble: "Let me...", "I'll now...", "I'm going to...", "Sure, I can..."
- No narration of tool calls: tool results speak for themselves
- No post-summary: "I've successfully...", "This completes...", "In summary..."
- No restating user's request back to them
- No explaining what you're about to do, then doing it, then explaining what you did
One of: action, result, or decision. Not all three.

## Targeted reads (rule TE-10)
Before reading a file, define what you need from it. Use offset+limit for known sections. Use grep to locate, then read only the relevant range. Never read a full file "to understand context" when you need 1 function or 1 section. Each unnecessary full-file read costs 1-3K tokens.
Exception: the 3-pass protocol (core-rule 5) authorizes full reads in pass 2 for large-file synthesis. TE-10 applies to exploratory reads, not synthesis reads.

## Tool call consolidation (rule TE-11)
Batch independent tool calls in a single turn. 3 sequential greps in 3 turns = 3x input context re-read. 3 parallel greps in 1 turn = 1x input context read. For vault work: glob + grep + read in parallel when targets are independent.

## Graduated response length (rule TE-12)
Match response length to task complexity:
- Trivial (file found, value confirmed, task done): 1 line
- Simple (edit made, grep result, status update): 2-3 lines
- Medium (decision needed, multiple findings): bullet list, no prose
- Complex (architecture, debugging, analysis): structured sections with headers
Default to shorter. Expand only when the information requires it.
Exception: uncertainty qualification (core-rule 7) and confidence tags (AS-1) are mandatory output, not verbosity. Include even in 1-line responses when applicable.

## Agent prompt efficiency (rule TE-13)
When dispatching agents: give the complete task in the initial prompt. Each follow-up message to an agent costs a full context re-read for that agent. One detailed prompt > three clarifying messages. Include: goal, constraints, expected output format, file paths if known.

## Avoid speculative exploration (rule TE-14)
Do not read files, grep, or search "just in case." Every tool call has a token cost. Before calling a tool, answer: "Do I need this result to proceed?" If the answer is "maybe," skip it and come back only if blocked. This applies especially to vault retrieval: follow the Engram layers, don't shotgun.
Exception: cross-reference (core-rule 9) and independent analysis (AS-5) are reads with a defined objective, not speculative exploration. TE-14 prohibits aimless reads, not source validation.

## Subagent budget per session (rule TE-15)
Soft cap of 8 subagents dispatched per session. After 8:
1. **Stop and evaluate**: is the task too large for one session?
2. **If yes**: suggest a new session (see `session-discipline.md`)
3. **If no**: proceed but log `[subagent-cap: N/8, justification]`

The cap exists because each subagent inherits context from the parent session. With 10+ subagents, the multiplied context cost exceeds the benefit of parallelization.

**Exception**: SDD pipelines with `/sdd-execute` may exceed the cap if there are 8+ independent issues. Log the exception.

## Effort level awareness (rule TE-16)
Since Claude Code 2.1.94, the default effort level changed from medium to high for API-key, Bedrock/Vertex/Foundry, Team, and Enterprise users. High effort = more reasoning tokens per turn = better quality but higher cost. For routine vault operations (scheduled tasks, syncs, maintenance), consider `/effort medium` to save tokens. Keep high for debugging, architecture, and multi-step reasoning. The agent should NOT change effort level autonomously, only suggest when appropriate.

## MCP result size override (rule TE-17)
Since Claude Code 2.1.91, MCP tools can annotate results with `_meta["anthropic/maxResultSizeChars"]` (up to 500K) to prevent truncation of large payloads like database schemas. When building custom MCPs or working with MCPs that return large results (Smart Connections, Notion queries with many pages), be aware that untruncated large results consume more context. If a large MCP result is only partially needed, summarize it before proceeding.

## Enforcement (auto-check)

Before each compaction or when reaching ~50% of the context window:
1. **MCP chain check:** If 5+ MCP calls were made without intermediate summarization, pause and summarize before continuing
2. **File read check:** If 3+ files were read in full (>200 lines each), verify the most important ones were read last (post-compact restore)
3. **WebSearch count:** Count WebSearch calls in the session. If >10, evaluate whether remaining ones can be batched
4. **Cache break check:** If CLAUDE.md or rules were edited mid-session, log: "[cache-break: {file edited}]"

These checks are guidance for the agent, not automated hooks. The agent should self-evaluate periodically.

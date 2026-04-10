---
name: sync-all
description: "Full sync: scan + external project syncs + health + connections. Use on Mondays, after days away from the vault, or when user wants to sync everything. Orchestrates sub-commands in sequence and produces a consolidated summary with next steps."
dependencies: "notion MCP, smart-connections MCP, vault-read"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash,Agent,mcp__notion__*,mcp__ob-smart-connections__*"
---

# /sync-all

Runs all syncs and checks in sequence. Ideal for the start of the week or returning after days away from the vault.

## Flow

Execute in order:

### 1. /scan 3
Scan files modified in the last 3 days.

### 2. External project syncs
Sync any external project folders to the vault. Configure your project mappings (e.g., external docs folder -> vault domain folder).

### 3. /health
Check vault health.

### 4. /connections
Discover new cross-domain connections.

### 5. Consolidated summary

```
Sync All -- YYYY-MM-DD

Scan: [N] files modified, [N] not documented
External syncs: [N] projects synced, [N] new
Health: [N/100] -- [classification]
Connections: [N] new connections suggested

Suggested next steps:
1. [most important action]
2. [second action]
3. [third action]
```

## Rules
- Each step is interactive -- pause for questions when needed
- If a step fails, continue with the next ones
- At the end, update the Daily Note with the sync log

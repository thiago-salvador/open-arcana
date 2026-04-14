#!/bin/bash
# PostToolUse hook: tracks iteration counts for background review trigger.
# Fires on every tool call. Maintains state file with:
#   - per_turn: iterations in current turn (reset by turn-boundary-check.sh)
#   - cumulative: total iterations since session start
#   - struggle_signals: count of error patterns in recent tool output
#
# Pattern inspired by NousResearch/hermes-agent nudge system, adapted for
# Open Arcana with signal-based trigger (struggle detection) not just raw counter.
#
# Concurrency: uses fcntl.flock(LOCK_EX) to prevent race conditions when
# multiple PostToolUse hooks fire in parallel. POSIX-compatible (macOS + Linux).
#
# State file: /tmp/claude-iter-state-YYYYMMDD.json

STATE_FILE="/tmp/claude-iter-state-$(date +%Y%m%d).json"

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', ''))
except:
    print('')
" 2>/dev/null)

TOOL_RESULT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    r = d.get('tool_response', {})
    if isinstance(r, dict):
        content = r.get('content', '') or r.get('output', '') or r.get('stderr', '')
        if isinstance(content, list):
            content = ' '.join(str(c.get('text', '') if isinstance(c, dict) else c) for c in content)
        print(str(content)[:500])
    else:
        print(str(r)[:500])
except:
    print('')
" 2>/dev/null)

# Detect struggle signals in tool output
STRUGGLE_INC=0
if echo "$TOOL_RESULT" | grep -qiE "(error|fail|exception|traceback|not found|denied|refused|No such file|syntax error|test failed|fatal)" 2>/dev/null; then
  STRUGGLE_INC=1
fi

# Update counters atomically via Python with fcntl lock
python3 <<PYEOF 2>/dev/null || true
import json, fcntl, os

state_file = "$STATE_FILE"
tool_name = "$TOOL_NAME"
struggle_inc = $STRUGGLE_INC

default_state = {"per_turn": 0, "cumulative": 0, "last_review_iter": 0, "struggle_signals": 0, "turn_tools": []}

try:
    if not os.path.exists(state_file):
        try:
            with open(state_file, "w") as f:
                json.dump(default_state, f)
        except (OSError, PermissionError):
            raise SystemExit(0)

    with open(state_file, "r+") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            f.seek(0)
            content = f.read()
            try:
                state = json.loads(content) if content.strip() else dict(default_state)
            except json.JSONDecodeError:
                state = dict(default_state)

            state["per_turn"] = state.get("per_turn", 0) + 1
            state["cumulative"] = state.get("cumulative", 0) + 1
            state["struggle_signals"] = state.get("struggle_signals", 0) + struggle_inc

            tt = state.get("turn_tools", [])
            tt.append(tool_name)
            state["turn_tools"] = tt[-30:]

            f.seek(0)
            f.truncate()
            json.dump(state, f)
            f.flush()
            os.fsync(f.fileno())
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)
except (OSError, PermissionError):
    pass
PYEOF

exit 0

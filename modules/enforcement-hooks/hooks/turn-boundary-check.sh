#!/bin/bash
# UserPromptSubmit hook: checks iteration state + adaptive thresholds.
#
# Adaptive thresholds: reads ~/.claude/review-history.json which contains
# outcomes from previous /background-review invocations. Rules:
#   - Last 5 all "nothing": raise thresholds (+2 distill, +1 struggle, +5 cumulative)
#     up to ceiling (14 / 9 / 25). Signal: heuristics too sensitive.
#   - Last 5 all "acted": lower thresholds (-1 / -1 / -3) down to floor (4 / 3 / 10).
#     Signal: heuristics too lax.
#   - Mixed or <5 outcomes: defaults unchanged.
#
# Default thresholds: distill=8, struggle=5, cumulative=15.
# Reset strategy: when a flag is emitted, last_review_iter advances to cumulative
# (prevents re-fire spam). Stale flag files from previous turns are deleted at start.
#
# Inspired by NousResearch/hermes-agent, adapted for Open Arcana.

STATE_FILE="/tmp/claude-iter-state-$(date +%Y%m%d).json"
FLAG_FILE="/tmp/claude-review-flag-$(date +%Y%m%d).txt"
HISTORY_FILE="$HOME/.claude/review-history.json"

# Stale flag cleanup
[ -f "$FLAG_FILE" ] && rm -f "$FLAG_FILE"

# No state = nothing to check
[ ! -f "$STATE_FILE" ] && exit 0

FLAGS=$(python3 <<PYEOF
import json
from pathlib import Path

STATE_FILE = "$STATE_FILE"
HISTORY_FILE = "$HISTORY_FILE"

DEFAULT_DISTILL = 8
DEFAULT_STRUGGLE = 5
DEFAULT_REVIEW = 15

FLOOR = {"distill": 4, "struggle": 3, "review": 10}
CEILING = {"distill": 14, "struggle": 9, "review": 25}

try:
    with open(STATE_FILE) as f:
        state = json.load(f)
except Exception:
    print("")
    raise SystemExit(0)

thresholds = {
    "distill": DEFAULT_DISTILL,
    "struggle": DEFAULT_STRUGGLE,
    "review": DEFAULT_REVIEW,
}

try:
    if Path(HISTORY_FILE).exists():
        with open(HISTORY_FILE) as f:
            hist_data = json.load(f)
        history = hist_data.get("history", []) if isinstance(hist_data, dict) else []
        if isinstance(history, list) and len(history) >= 5:
            last5 = history[-5:]
            outcomes = [h.get("outcome", "") for h in last5 if isinstance(h, dict)]
            if len(outcomes) == 5 and all(o == "nothing" for o in outcomes):
                thresholds["distill"] = min(DEFAULT_DISTILL + 2, CEILING["distill"])
                thresholds["struggle"] = min(DEFAULT_STRUGGLE + 1, CEILING["struggle"])
                thresholds["review"] = min(DEFAULT_REVIEW + 5, CEILING["review"])
            elif len(outcomes) == 5 and all(o == "acted" for o in outcomes):
                thresholds["distill"] = max(DEFAULT_DISTILL - 1, FLOOR["distill"])
                thresholds["struggle"] = max(DEFAULT_STRUGGLE - 1, FLOOR["struggle"])
                thresholds["review"] = max(DEFAULT_REVIEW - 3, FLOOR["review"])
        if isinstance(hist_data, dict):
            hist_data["current_thresholds"] = thresholds
            with open(HISTORY_FILE, "w") as f:
                json.dump(hist_data, f, indent=2)
except Exception:
    pass

per_turn = max(state.get("per_turn", 0), 0)
cumulative = max(state.get("cumulative", 0), 0)
last_review = state.get("last_review_iter", 0)
struggle = max(state.get("struggle_signals", 0), 0)
turn_tools = state.get("turn_tools", [])

flags = []

distill_threshold = thresholds["struggle"] if struggle >= 2 else thresholds["distill"]
if per_turn >= distill_threshold:
    flags.append(f"distill|per_turn={per_turn}|struggle={struggle}|threshold={distill_threshold}|tools={','.join(turn_tools[-10:])}")

iters_since_review = cumulative - last_review
if iters_since_review >= thresholds["review"]:
    flags.append(f"review|iters_since_review={iters_since_review}|cumulative={cumulative}|threshold={thresholds['review']}")

state["per_turn"] = 0
state["struggle_signals"] = 0
state["turn_tools"] = []

if flags:
    state["last_review_iter"] = cumulative

try:
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)
except (OSError, PermissionError):
    pass

print("\n".join(flags))
PYEOF
)

[ -z "$FLAGS" ] && exit 0

echo "$FLAGS" > "$FLAG_FILE"

MSG="REVIEW FLAG: "
if echo "$FLAGS" | grep -q "^distill"; then
  DETAILS=$(echo "$FLAGS" | grep "^distill" | head -1)
  MSG+="Previous turn had trial-and-error pattern ($DETAILS). "
fi
if echo "$FLAGS" | grep -q "^review"; then
  DETAILS=$(echo "$FLAGS" | grep "^review" | head -1)
  MSG+="Cumulative iteration threshold crossed ($DETAILS). "
fi
MSG+="Before answering the user, invoke the Task tool with subagent_type=general-purpose and prompt=/background-review. Review outcome will be recorded to ~/.claude/review-history.json, driving adaptive thresholds on future turns."

echo "{\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"additionalContext\":\"$MSG\"}}"
exit 0

#!/usr/bin/env python3
"""
Claude Code analytics engine.
Computes behavioral metrics from ~/.claude/projects/ JSONL files.
Outputs data.json to the vault's 00-Dashboard/ directory.

Usage:
  python3 analytics_engine.py
  SINCE_DAYS=7 python3 analytics_engine.py
  SINCE_DATE=2026-04-01 python3 analytics_engine.py
  VAULT_PATH=/path/to/vault python3 analytics_engine.py

Environment variables:
  SINCE_DAYS   - Only include sessions from the last N days (default: 7)
  SINCE_DATE   - Only include sessions since this date (YYYY-MM-DD)
  VAULT_PATH   - Output directory (default: auto-detect)
"""

import json
import os
import re
import sys
from pathlib import Path
from collections import defaultdict
from datetime import datetime, timedelta, timezone

PROJECTS_DIR = Path.home() / ".claude" / "projects"

USERNAME = os.environ.get("USERNAME", Path.home().name)
VAULT_PATH = os.environ.get("VAULT_PATH", "")
SINCE_DAYS = int(os.environ.get("SINCE_DAYS", "7")) or None
SINCE_DATE = os.environ.get("SINCE_DATE")

# Pricing (USD per million tokens) - Claude Opus 4.6
PRICING = {
    "input_tokens": 15.0,
    "cache_creation_input_tokens": 18.75,
    "cache_read_input_tokens": 1.50,
    "output_tokens": 75.0,
}
FAST_MODE_MULTIPLIER = 6.0

# Frustration keywords
FRUSTRATION_KEYWORDS = re.compile(
    r"\b(wrong|broken|still|again|not working|wtf|ugh|no that|stop)\b", re.IGNORECASE
)


# ── Utility functions (reused from token_analysis.py pattern) ──


def extract_text_content(content):
    """Extract text from message content (string or list)."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, dict):
                if item.get("type") == "text":
                    parts.append(item.get("text", ""))
            elif isinstance(item, str):
                parts.append(item)
        return "\n".join(parts).strip()
    return ""


def is_human_prompt(msg_obj):
    """Check if this is a human-originated prompt (not tool result)."""
    content = msg_obj.get("message", {}).get("content", "")
    if isinstance(content, list):
        types = [i.get("type") for i in content if isinstance(i, dict)]
        if types and all(t == "tool_result" for t in types):
            return False
    return True


def get_project_name(project_dir_name):
    """Convert directory name to readable project name."""
    name = project_dir_name
    prefixes = [f"-Users-{USERNAME}-Documents-", f"-Users-{USERNAME}-"]
    for p in prefixes:
        if name.startswith(p):
            name = name[len(p):]
            break
    name = name.replace("Apps-", "").replace("Obsidian-", "Vault/")
    return name or project_dir_name


def get_cutoff():
    """Return a UTC-aware datetime cutoff, or None for all time."""
    if SINCE_DATE:
        return datetime.fromisoformat(SINCE_DATE).replace(tzinfo=timezone.utc)
    if SINCE_DAYS:
        return datetime.now(timezone.utc) - timedelta(days=SINCE_DAYS)
    return None


def session_in_range(session, cutoff):
    if not cutoff or not session.get("timestamp_start"):
        return True
    ts_str = session["timestamp_start"]
    try:
        ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        return ts >= cutoff
    except ValueError:
        return True


def calculate_cost(usage, fast_mode=True):
    """Calculate estimated USD cost from token usage."""
    cost = 0.0
    for token_type, price_per_mtok in PRICING.items():
        tokens = usage.get(token_type, 0)
        cost += (tokens / 1_000_000) * price_per_mtok
    if fast_mode:
        cost *= FAST_MODE_MULTIPLIER
    return cost


def parse_session_lines(jsonl_path):
    """Parse a JSONL file and return list of parsed line objects."""
    try:
        with open(jsonl_path) as f:
            raw_lines = f.readlines()
    except Exception:
        return []

    parsed = []
    for line in raw_lines:
        try:
            parsed.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return parsed


def parse_session(jsonl_path, is_subagent=False):
    """Parse a single JSONL session file."""
    usage_total = defaultdict(int)
    prompts = []
    agent_id = None
    session_id = None
    timestamp_start = None
    timestamp_end = None
    subagent_sessions = []
    model_used = None

    lines = parse_session_lines(jsonl_path)
    if not lines:
        return None

    for obj in lines:
        msg_type = obj.get("type")
        ts = obj.get("timestamp")
        if ts and not timestamp_start:
            timestamp_start = ts
        if ts:
            timestamp_end = ts

        if not agent_id:
            agent_id = obj.get("agentId")
        if not session_id:
            session_id = obj.get("sessionId")

        if msg_type == "assistant":
            msg = obj.get("message", {})
            usage = msg.get("usage", {})
            usage_total["input_tokens"] += usage.get("input_tokens", 0)
            usage_total["cache_creation_input_tokens"] += usage.get("cache_creation_input_tokens", 0)
            usage_total["cache_read_input_tokens"] += usage.get("cache_read_input_tokens", 0)
            usage_total["output_tokens"] += usage.get("output_tokens", 0)
            if not model_used and msg.get("model"):
                model_used = msg.get("model")

        elif msg_type == "user":
            user_type = obj.get("userType", "")
            is_sidechain = obj.get("isSidechain", False)
            content = obj.get("message", {}).get("content", "")
            text = extract_text_content(content)

            if text and not is_sidechain and is_human_prompt(obj) and user_type != "tool":
                prompts.append({
                    "text": text,
                    "timestamp": obj.get("timestamp"),
                    "entrypoint": obj.get("entrypoint", ""),
                })

    # Check for subagent sessions
    session_dir = jsonl_path.parent / jsonl_path.stem
    if session_dir.is_dir():
        subagents_dir = session_dir / "subagents"
        if subagents_dir.is_dir():
            for sub_file in subagents_dir.glob("*.jsonl"):
                sub_data = parse_session(sub_file, is_subagent=True)
                if sub_data:
                    sub_data["subagent_file"] = str(sub_file.name)
                    subagent_sessions.append(sub_data)

    total_tokens = (
        usage_total["input_tokens"]
        + usage_total["cache_creation_input_tokens"]
        + usage_total["cache_read_input_tokens"]
        + usage_total["output_tokens"]
    )

    return {
        "file": str(jsonl_path),
        "session_id": session_id or jsonl_path.stem,
        "agent_id": agent_id,
        "is_subagent": is_subagent,
        "timestamp_start": timestamp_start,
        "timestamp_end": timestamp_end,
        "model": model_used,
        "usage": dict(usage_total),
        "total_tokens": total_tokens,
        "prompts": prompts,
        "subagent_sessions": subagent_sessions,
        "lines": lines,
    }


def analyze_all():
    """Analyze all projects and sessions."""
    projects = defaultdict(list)
    cutoff = get_cutoff()

    if not PROJECTS_DIR.is_dir():
        return projects

    for project_dir in sorted(PROJECTS_DIR.iterdir()):
        if not project_dir.is_dir():
            continue
        project_name = get_project_name(project_dir.name)

        for jsonl_file in sorted(project_dir.glob("*.jsonl")):
            session = parse_session(jsonl_file)
            if session and session["total_tokens"] > 0 and session_in_range(session, cutoff):
                projects[project_name].append(session)

    return projects


# ── Metric functions ──


def compute_hir(session):
    """Human Intervention Rate: intervention prompts / total tool calls."""
    lines = session.get("lines", [])
    tool_calls = 0
    interventions = 0

    i = 0
    while i < len(lines):
        obj = lines[i]
        msg_type = obj.get("type")

        if msg_type == "assistant":
            msg = obj.get("message", {})
            content = msg.get("content", [])
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "tool_use":
                        tool_calls += 1

        elif msg_type == "user" and tool_calls > 0:
            # Check if this is a human re-prompt (not a tool_result)
            if is_human_prompt(obj):
                user_type = obj.get("userType", "")
                is_sidechain = obj.get("isSidechain", False)
                if not is_sidechain and user_type != "tool":
                    text = extract_text_content(obj.get("message", {}).get("content", ""))
                    if text:
                        interventions += 1

        i += 1

    rate = interventions / tool_calls if tool_calls > 0 else 0.0
    return {"interventions": interventions, "tool_calls": tool_calls, "rate": round(rate, 4)}


def compute_context_fill(session):
    """Track cumulative input_tokens from each assistant message."""
    lines = session.get("lines", [])
    fill_points = []
    cumulative = 0
    msg_index = 0

    for obj in lines:
        if obj.get("type") == "assistant":
            usage = obj.get("message", {}).get("usage", {})
            input_t = usage.get("input_tokens", 0)
            cumulative += input_t
            fill_points.append([msg_index, cumulative])
            msg_index += 1

    return fill_points


def compute_frustration(session):
    """Score 0-10 per session based on frustration signals."""
    prompts = session.get("prompts", [])
    score = 0

    # Check repeated prompts (same text within 3 messages)
    for i, p in enumerate(prompts):
        window = prompts[max(0, i - 3):i]
        for prev in window:
            if p["text"].strip() == prev["text"].strip():
                score += 2
                break

    # Check negative keywords
    frustration_positions = []
    for i, p in enumerate(prompts):
        matches = FRUSTRATION_KEYWORDS.findall(p["text"])
        score += len(matches)
        if matches:
            frustration_positions.append(i)

    # Early abandonment: session ends within 2 messages of a frustration signal
    if frustration_positions and len(prompts) > 0:
        last_frustration = max(frustration_positions)
        if len(prompts) - last_frustration <= 2:
            score += 3

    return min(score, 10)


def compute_tool_precision(session):
    """Parse tool_use + tool_result pairs. Count success/failure."""
    lines = session.get("lines", [])
    success = 0
    failure = 0
    total = 0

    # Collect tool_use IDs from assistant messages, then match with tool_results
    pending_tools = {}

    for obj in lines:
        msg_type = obj.get("type")

        if msg_type == "assistant":
            content = obj.get("message", {}).get("content", [])
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "tool_use":
                        tool_id = block.get("id", "")
                        if tool_id:
                            pending_tools[tool_id] = True
                            total += 1

        elif msg_type == "user":
            content = obj.get("message", {}).get("content", [])
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "tool_result":
                        tool_id = block.get("tool_use_id", "")
                        is_error = block.get("is_error", False)
                        if tool_id in pending_tools:
                            if is_error:
                                failure += 1
                            else:
                                success += 1
                            del pending_tools[tool_id]

    precision = success / total if total > 0 else 1.0
    return {"success": success, "failure": failure, "total": total, "precision": round(precision, 4)}


def compute_command_frequency(session):
    """Regex scan prompts for /command patterns (slash commands only, not paths)."""
    freq = defaultdict(int)
    # Match /word at start of line or after whitespace, exclude filesystem paths
    path_segments = {"users", "home", "usr", "var", "tmp", "etc", "opt", "bin", "lib", "dev", "proc", "sys", "mnt"}
    for p in session.get("prompts", []):
        # Only match /word that looks like a command (start of text or after whitespace)
        matches = re.findall(r"(?:^|\s)/([a-z][\w-]*)", p["text"], re.IGNORECASE)
        for cmd in matches:
            if cmd.lower() not in path_segments and len(cmd) > 1:
                freq[cmd] += 1
    return dict(freq)


def compute_subagent_efficiency(session):
    """Subagent tokens as ratio of total session tokens."""
    subagent_tokens = 0
    for sub in session.get("subagent_sessions", []):
        subagent_tokens += sub.get("total_tokens", 0)

    total_tokens = session.get("total_tokens", 0) + subagent_tokens
    ratio = subagent_tokens / total_tokens if total_tokens > 0 else 0.0
    return {
        "subagent_tokens": subagent_tokens,
        "total_tokens": total_tokens,
        "ratio": round(ratio, 4),
    }


# ── Main ──


def get_output_dir():
    if VAULT_PATH:
        return Path(VAULT_PATH) / "00-Dashboard"
    return Path("00-Dashboard")


def main():
    print("Scanning projects...")
    projects = analyze_all()
    print(f"Found {len(projects)} projects")

    summary = {
        "total_cost": 0.0,
        "total_sessions": 0,
        "total_tokens": 0,
        "avg_hir": 0.0,
        "avg_frustration": 0.0,
        "avg_tool_precision": 0.0,
    }
    daily = defaultdict(lambda: {"sessions": 0, "tokens": 0, "cost": 0.0, "hir": 0.0, "frustration": 0})
    project_stats = []
    costly_sessions = []
    command_freq = defaultdict(int)
    context_fills = []
    heatmap = defaultdict(lambda: defaultdict(int))

    all_hirs = []
    all_frustrations = []
    all_precisions = []

    for project_name, sessions in projects.items():
        proj_cost = 0.0
        proj_tokens = 0
        proj_sessions = len(sessions)

        for session in sessions:
            cost = calculate_cost(session["usage"])
            tokens = session["total_tokens"]

            # Compute metrics
            hir = compute_hir(session)
            frustration = compute_frustration(session)
            tool_prec = compute_tool_precision(session)
            cmd_freq = compute_command_frequency(session)
            subagent_eff = compute_subagent_efficiency(session)
            ctx_fill = compute_context_fill(session)

            all_hirs.append(hir["rate"])
            all_frustrations.append(frustration)
            all_precisions.append(tool_prec["precision"])

            summary["total_cost"] += cost
            summary["total_sessions"] += 1
            summary["total_tokens"] += tokens
            proj_cost += cost
            proj_tokens += tokens

            # Daily aggregation
            if session.get("timestamp_start"):
                day = session["timestamp_start"][:10]
                daily[day]["sessions"] += 1
                daily[day]["tokens"] += tokens
                daily[day]["cost"] += cost
                daily[day]["hir"] += hir["rate"]
                daily[day]["frustration"] += frustration

                # Heatmap: day-of-week x hour
                try:
                    ts = datetime.fromisoformat(session["timestamp_start"].replace("Z", "+00:00"))
                    dow = ts.strftime("%a")
                    hour = ts.hour
                    heatmap[dow][hour] += tokens
                except (ValueError, AttributeError):
                    pass

            # Costly sessions list
            first_prompt = ""
            if session["prompts"]:
                first_prompt = session["prompts"][0]["text"][:200]
            costly_sessions.append({
                "project": project_name,
                "session_id": session["session_id"],
                "timestamp": session.get("timestamp_start", ""),
                "tokens": tokens,
                "cost": round(cost, 4),
                "hir": hir["rate"],
                "frustration": frustration,
                "tool_precision": tool_prec["precision"],
                "first_prompt": first_prompt,
            })

            # Command frequency
            for cmd, count in cmd_freq.items():
                command_freq[cmd] += count

            # Context fills (keep top sessions by token count)
            if ctx_fill:
                context_fills.append({
                    "session_id": session["session_id"],
                    "project": project_name,
                    "fill": ctx_fill,
                })

            # Remove raw lines to save memory before JSON output
            session.pop("lines", None)

        project_stats.append({
            "project": project_name,
            "sessions": proj_sessions,
            "tokens": proj_tokens,
            "cost": round(proj_cost, 4),
        })

    # Averages
    if all_hirs:
        summary["avg_hir"] = round(sum(all_hirs) / len(all_hirs), 4)
    if all_frustrations:
        summary["avg_frustration"] = round(sum(all_frustrations) / len(all_frustrations), 2)
    if all_precisions:
        summary["avg_tool_precision"] = round(sum(all_precisions) / len(all_precisions), 4)

    summary["total_cost"] = round(summary["total_cost"], 2)

    # Sort
    costly_sessions.sort(key=lambda x: x["cost"], reverse=True)
    project_stats.sort(key=lambda x: x["cost"], reverse=True)
    context_fills.sort(key=lambda x: len(x["fill"]), reverse=True)

    sorted_daily = []
    for day in sorted(daily.keys()):
        d = daily[day]
        avg_hir = d["hir"] / d["sessions"] if d["sessions"] > 0 else 0
        avg_frust = d["frustration"] / d["sessions"] if d["sessions"] > 0 else 0
        sorted_daily.append({
            "date": day,
            "sessions": d["sessions"],
            "tokens": d["tokens"],
            "cost": round(d["cost"], 4),
            "avg_hir": round(avg_hir, 4),
            "avg_frustration": round(avg_frust, 2),
        })

    output = {
        "generated": datetime.now(timezone.utc).isoformat(),
        "range": f"last {SINCE_DAYS or 'all'} days",
        "summary": summary,
        "daily": sorted_daily,
        "projects": project_stats,
        "costly_sessions": costly_sessions[:20],
        "command_frequency": dict(command_freq),
        "context_fills": context_fills[:10],
        "heatmap": {dow: dict(hours) for dow, hours in heatmap.items()},
    }

    output_path = get_output_dir() / "data.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(output, f, indent=2)

    print(f"\nAnalytics written to {output_path}")
    print(f"\n--- Summary ---")
    print(f"Sessions: {summary['total_sessions']}")
    print(f"Total cost: ${summary['total_cost']:.2f}")
    print(f"Avg HIR: {summary['avg_hir']:.2%}")
    print(f"Avg Frustration: {summary['avg_frustration']:.1f}/10")
    print(f"Avg Tool Precision: {summary['avg_tool_precision']:.2%}")

    # Top commands
    if command_freq:
        top_cmds = sorted(command_freq.items(), key=lambda x: x[1], reverse=True)[:3]
        print(f"Top commands: {', '.join(f'/{c} ({n})' for c, n in top_cmds)}")


if __name__ == "__main__":
    main()

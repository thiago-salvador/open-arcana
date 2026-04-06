#!/usr/bin/env python3
"""
Claude Code token usage analyzer.
Analyzes ~/.claude/projects/ JSONL files for token usage patterns.
Outputs markdown report to the vault's 00-Dashboard/ directory.

Usage:
  python3 token_analysis.py                       # All time
  SINCE_DAYS=7 python3 token_analysis.py          # Last 7 days
  SINCE_DATE=2026-04-01 python3 token_analysis.py # Since date
  VAULT_PATH=/path/to/vault python3 token_analysis.py  # Custom vault

Environment variables:
  SINCE_DAYS   - Only include sessions from the last N days
  SINCE_DATE   - Only include sessions since this date (YYYY-MM-DD)
  VAULT_PATH   - Output directory (default: auto-detect from first project)
  USERNAME     - Username for path stripping (default: auto-detect)
"""

import json
import os
import sys
from pathlib import Path
from collections import defaultdict
from datetime import datetime, timedelta, timezone

PROJECTS_DIR = Path.home() / ".claude" / "projects"

# Auto-detect username from home directory
USERNAME = os.environ.get("USERNAME", Path.home().name)

# Output: vault's 00-Dashboard/ or current directory
VAULT_PATH = os.environ.get("VAULT_PATH", "")

# Filter
SINCE_DAYS = int(os.environ.get("SINCE_DAYS", "0")) or None
SINCE_DATE = os.environ.get("SINCE_DATE")

# Pricing (USD per million tokens) - Claude Opus 4.6
# Standard: $15 input, $75 output
# Cache creation: $18.75/MTok, Cache read: $1.50/MTok
PRICING = {
    "input_tokens": 15.0,
    "cache_creation_input_tokens": 18.75,
    "cache_read_input_tokens": 1.50,
    "output_tokens": 75.0,
}

# Fast mode multiplier (6x for Max subscribers)
FAST_MODE_MULTIPLIER = 6.0


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

    try:
        with open(jsonl_path) as f:
            lines = f.readlines()
    except Exception:
        return None

    for line in lines:
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

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
    }


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
    if not cutoff or not session["timestamp_start"]:
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


def analyze_all():
    """Analyze all projects and sessions."""
    projects = defaultdict(list)
    cutoff = get_cutoff()

    for project_dir in sorted(PROJECTS_DIR.iterdir()):
        if not project_dir.is_dir():
            continue
        project_name = get_project_name(project_dir.name)

        for jsonl_file in sorted(project_dir.glob("*.jsonl")):
            session = parse_session(jsonl_file)
            if session and session["total_tokens"] > 0 and session_in_range(session, cutoff):
                projects[project_name].append(session)

    return projects


def format_tokens(n):
    return f"{n:,}"


def format_cost(cost):
    if cost >= 1.0:
        return f"${cost:.2f}"
    return f"${cost:.3f}"


def summarize_projects(projects):
    summaries = []
    for project_name, sessions in projects.items():
        total = defaultdict(int)
        all_subagent_tokens = 0
        subagent_count = 0

        for session in sessions:
            for k, v in session["usage"].items():
                total[k] += v
            for sub in session["subagent_sessions"]:
                all_subagent_tokens += sub["total_tokens"]
                subagent_count += 1

        grand_total = sum(total.values())
        cost = calculate_cost(dict(total))

        summaries.append({
            "project": project_name,
            "sessions": len(sessions),
            "usage": dict(total),
            "total_tokens": grand_total,
            "cost_usd": cost,
            "subagent_tokens": all_subagent_tokens,
            "subagent_count": subagent_count,
        })

    summaries.sort(key=lambda x: x["total_tokens"], reverse=True)
    return summaries


def find_costly_sessions(projects, top_n=20):
    all_sessions = []
    for project_name, sessions in projects.items():
        for session in sessions:
            all_sessions.append((project_name, session))
    all_sessions.sort(key=lambda x: x[1]["total_tokens"], reverse=True)
    return all_sessions[:top_n]


def find_costly_subagents(projects, top_n=20):
    all_subs = []
    for project_name, sessions in projects.items():
        for session in sessions:
            for sub in session["subagent_sessions"]:
                all_subs.append((project_name, session["session_id"], sub))
    all_subs.sort(key=lambda x: x[2]["total_tokens"], reverse=True)
    return all_subs[:top_n]


def get_output_dir():
    """Determine output directory."""
    if VAULT_PATH:
        return Path(VAULT_PATH) / "00-Dashboard"
    return Path("00-Dashboard")


def write_report(projects, summaries):
    output_dir = get_output_dir()
    output_dir.mkdir(parents=True, exist_ok=True)
    report_path = output_dir / "token-report.md"

    lines = []
    cutoff = get_cutoff()
    date_range = f"Since {cutoff.strftime('%Y-%m-%d')}" if cutoff else "All time"
    lines.append("---")
    lines.append('title: "Token Usage Report"')
    lines.append('type: reference')
    lines.append('domain: personal')
    lines.append('tags: [token-economy, analytics, claude-code]')
    lines.append('status: active')
    lines.append(f'created: {datetime.now().strftime("%Y-%m-%d")}')
    lines.append("---")
    lines.append("")
    lines.append("# Claude Code Token Usage Analysis")
    lines.append(f"\nGenerated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | Range: {date_range}")
    lines.append(f"Pricing: Opus 4.6 with Fast Mode (6x) | Input $90/MTok, Output $450/MTok, Cache Read $9/MTok\n")

    # Grand totals
    grand_input = sum(s["usage"].get("input_tokens", 0) for s in summaries)
    grand_cache_create = sum(s["usage"].get("cache_creation_input_tokens", 0) for s in summaries)
    grand_cache_read = sum(s["usage"].get("cache_read_input_tokens", 0) for s in summaries)
    grand_output = sum(s["usage"].get("output_tokens", 0) for s in summaries)
    grand_total = sum(s["total_tokens"] for s in summaries)
    grand_cost = sum(s["cost_usd"] for s in summaries)
    total_sessions = sum(s["sessions"] for s in summaries)
    total_subagent_tokens = sum(s["subagent_tokens"] for s in summaries)
    total_subagent_count = sum(s["subagent_count"] for s in summaries)

    lines.append("## Grand Totals\n")
    lines.append(f"- **Projects**: {len(summaries)}")
    lines.append(f"- **Sessions**: {total_sessions:,}")
    lines.append(f"- **Total tokens**: {format_tokens(grand_total)}")
    lines.append(f"  - Input: {format_tokens(grand_input)}")
    lines.append(f"  - Cache creation: {format_tokens(grand_cache_create)}")
    lines.append(f"  - Cache read: {format_tokens(grand_cache_read)}")
    lines.append(f"  - Output: {format_tokens(grand_output)}")
    lines.append(f"- **Estimated cost (fast mode)**: {format_cost(grand_cost)}")
    lines.append(f"- **Subagent sessions**: {total_subagent_count:,} ({format_tokens(total_subagent_tokens)} tokens)")
    lines.append("")

    # Per-project breakdown
    lines.append("## By Project\n")
    lines.append("| Project | Sessions | Total Tokens | Cost (USD) | Input | Cache Create | Cache Read | Output | Subagents |")
    lines.append("|---------|----------|-------------|------------|-------|-------------|------------|--------|-----------|")

    for s in summaries:
        u = s["usage"]
        lines.append(
            f"| {s['project']} | {s['sessions']} "
            f"| {format_tokens(s['total_tokens'])} "
            f"| {format_cost(s['cost_usd'])} "
            f"| {format_tokens(u.get('input_tokens', 0))} "
            f"| {format_tokens(u.get('cache_creation_input_tokens', 0))} "
            f"| {format_tokens(u.get('cache_read_input_tokens', 0))} "
            f"| {format_tokens(u.get('output_tokens', 0))} "
            f"| {s['subagent_count']} ({format_tokens(s['subagent_tokens'])}) |"
        )
    lines.append("")

    # Most costly sessions
    lines.append("## Most Costly Sessions\n")
    costly = find_costly_sessions(projects, top_n=25)
    for i, (proj, session) in enumerate(costly, 1):
        cost = calculate_cost(session["usage"])
        lines.append(f"### {i}. {proj} ({format_cost(cost)}, {format_tokens(session['total_tokens'])} tokens)")
        lines.append(f"- **Session**: `{session['session_id']}`")
        if session["timestamp_start"]:
            lines.append(f"- **Started**: {session['timestamp_start'][:19].replace('T', ' ')}")
        u = session["usage"]
        lines.append(f"- **Tokens**: input={format_tokens(u.get('input_tokens', 0))}, cache_create={format_tokens(u.get('cache_creation_input_tokens', 0))}, cache_read={format_tokens(u.get('cache_read_input_tokens', 0))}, output={format_tokens(u.get('output_tokens', 0))}")
        lines.append(f"- **Subagents in session**: {len(session['subagent_sessions'])}")
        if session["prompts"]:
            lines.append("- **First prompt**:")
            first = session["prompts"][0]["text"][:400].replace("\n", " ")
            lines.append(f"  > {first}")
        lines.append("")

    # Most costly subagents
    lines.append("## Most Costly Subagents\n")
    costly_subs = find_costly_subagents(projects, top_n=20)
    lines.append("| # | Project | Parent Session | Subagent File | Total Tokens | Cost | Input | Output |")
    lines.append("|---|---------|----------------|---------------|-------------|------|-------|--------|")
    for i, (proj, session_id, sub) in enumerate(costly_subs, 1):
        u = sub["usage"]
        sub_cost = calculate_cost(u)
        lines.append(
            f"| {i} | {proj} | `{session_id[:8]}...` "
            f"| `{sub.get('subagent_file', '?')}` "
            f"| {format_tokens(sub['total_tokens'])} "
            f"| {format_cost(sub_cost)} "
            f"| {format_tokens(u.get('input_tokens', 0) + u.get('cache_creation_input_tokens', 0) + u.get('cache_read_input_tokens', 0))} "
            f"| {format_tokens(u.get('output_tokens', 0))} |"
        )
    lines.append("")

    # Daily trend
    lines.append("## Daily Trend (last 14 days)\n")
    daily = defaultdict(lambda: {"tokens": 0, "cost": 0.0, "sessions": 0})
    for proj_name, sessions in projects.items():
        for session in sessions:
            if session["timestamp_start"]:
                try:
                    day = session["timestamp_start"][:10]
                    daily[day]["tokens"] += session["total_tokens"]
                    daily[day]["cost"] += calculate_cost(session["usage"])
                    daily[day]["sessions"] += 1
                except Exception:
                    pass

    sorted_days = sorted(daily.keys(), reverse=True)[:14]
    lines.append("| Date | Sessions | Tokens | Est. Cost |")
    lines.append("|------|----------|--------|-----------|")
    for day in sorted_days:
        d = daily[day]
        lines.append(f"| {day} | {d['sessions']} | {format_tokens(d['tokens'])} | {format_cost(d['cost'])} |")
    lines.append("")

    with open(report_path, "w") as f:
        f.write("\n".join(lines))

    print(f"Report written: {report_path}")
    return report_path


def print_summary(summaries, projects):
    grand_total = sum(s["total_tokens"] for s in summaries)
    grand_cost = sum(s["cost_usd"] for s in summaries)
    total_sessions = sum(s["sessions"] for s in summaries)

    print(f"\nTotal: {format_tokens(grand_total)} tokens ({format_cost(grand_cost)}) across {total_sessions} sessions in {len(summaries)} projects\n")
    print(f"{'Project':<50}{'Sessions':>8}{'Total Tokens':>14}{'Cost':>10}{'Subagents':>10}")
    print("-" * 96)

    for s in summaries[:30]:
        print(
            f"{s['project']:<50}{s['sessions']:>8,}{format_tokens(s['total_tokens']):>14}{format_cost(s['cost_usd']):>10}{s['subagent_count']:>10,}"
        )

    print("\nTop 10 costliest sessions:")
    for proj, session in find_costly_sessions(projects, top_n=10):
        ts = session["timestamp_start"][:10] if session["timestamp_start"] else "?"
        cost = calculate_cost(session["usage"])
        first_prompt = ""
        if session["prompts"]:
            first_prompt = session["prompts"][0]["text"][:80].replace("\n", " ")
        print(f"  [{ts}] {proj}: {format_tokens(session['total_tokens'])} ({format_cost(cost)}) -- {first_prompt}")


def main():
    print("Scanning projects...")
    projects = analyze_all()
    print(f"Found {len(projects)} projects")
    summaries = summarize_projects(projects)
    print_summary(summaries, projects)
    report_path = write_report(projects, summaries)
    print(f"\nFull report: {report_path}")


if __name__ == "__main__":
    main()

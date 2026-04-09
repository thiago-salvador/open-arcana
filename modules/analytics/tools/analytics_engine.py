#!/usr/bin/env python3
"""
Claude Code analytics engine.
Computes behavioral metrics from ~/.claude/projects/ JSONL files.
Outputs data.json (and optionally embeds into analytics.html) to the vault's
00-Dashboard/ directory.

Usage:
  python3 analytics_engine.py
  SINCE_DAYS=7 python3 analytics_engine.py
  SINCE_DATE=2026-04-01 python3 analytics_engine.py
  VAULT_PATH=/path/to/vault python3 analytics_engine.py
  python3 analytics_engine.py --stdout

Environment variables:
  SINCE_DAYS   - Only include sessions from the last N days (default: 7)
  SINCE_DATE   - Only include sessions since this date (YYYY-MM-DD)
  VAULT_PATH   - Output directory (default: current directory)
"""

import json
import os
import re
import sys
from pathlib import Path
from collections import defaultdict, Counter
from datetime import datetime, timedelta, timezone

PROJECTS_DIR = Path.home() / ".claude" / "projects"
USERNAME = Path.home().name

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

FRUSTRATION_KEYWORDS = re.compile(
    r"\b(wrong|broken|still not|again|not working|wtf|ugh|no that's|stop|nao|errado|quebrou|de novo)\b",
    re.IGNORECASE,
)

COMMAND_PATTERN = re.compile(r"^/(\w[\w-]*)")


# ── Utility functions ──


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


def calculate_cost(usage, fast_mode=True):
    """Calculate estimated USD cost from token usage."""
    cost = 0.0
    for token_type, price_per_mtok in PRICING.items():
        tokens = usage.get(token_type, 0)
        cost += (tokens / 1_000_000) * price_per_mtok
    if fast_mode:
        cost *= FAST_MODE_MULTIPLIER
    return cost


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


def get_domain(project_dir_name):
    """Map project directory name to a domain label."""
    name = get_project_name(project_dir_name)
    if "/" in name:
        return name.split("/")[0].lower()
    return name.lower() if name else "other"


def get_cutoff():
    """Return a UTC-aware datetime cutoff, or None for all time."""
    if SINCE_DATE:
        return datetime.fromisoformat(SINCE_DATE).replace(tzinfo=timezone.utc)
    if SINCE_DAYS:
        return datetime.now(timezone.utc) - timedelta(days=SINCE_DAYS)
    return None


def session_in_range(timestamp_start, cutoff):
    """Check if session timestamp is within range."""
    if not cutoff or not timestamp_start:
        return True
    try:
        ts = datetime.fromisoformat(timestamp_start.replace("Z", "+00:00"))
        return ts >= cutoff
    except ValueError:
        return True


def word_set(text):
    """Get set of lowercase words from text."""
    return set(re.findall(r"\w+", text.lower()))


def similarity_ratio(text1, text2):
    """Simple word overlap ratio between two texts."""
    w1 = word_set(text1)
    w2 = word_set(text2)
    if not w1 or not w2:
        return 0.0
    common = w1 & w2
    return len(common) / max(len(w1), len(w2))


# ── Single-pass session parser with all metrics ──


def parse_session_full(jsonl_path):
    """Parse a single JSONL session file and compute all 6 metrics in one pass."""
    usage_total = defaultdict(int)
    prompts = []
    session_id = None
    timestamp_start = None
    timestamp_end = None
    model_used = None

    # HIR
    tool_calls_total = 0
    intervention_prompts = 0
    last_was_tool_error = False

    # Tool precision
    tool_results = defaultdict(lambda: {"success": 0, "failure": 0})
    pending_tool_uses = {}

    # Context fill rate
    context_points = []
    cumulative_input = 0

    # Commands/skills
    commands = []
    skills = []

    # Frustration
    frustration_score = 0
    human_texts = []
    last_frustration_msg_idx = -999

    # Subagents
    subagent_tokens = 0
    subagent_count = 0

    msg_index = 0

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

        if not session_id:
            session_id = obj.get("sessionId")

        if msg_type == "assistant":
            msg = obj.get("message", {})
            usage = msg.get("usage", {})
            input_tok = usage.get("input_tokens", 0)
            usage_total["input_tokens"] += input_tok
            usage_total["cache_creation_input_tokens"] += usage.get("cache_creation_input_tokens", 0)
            usage_total["cache_read_input_tokens"] += usage.get("cache_read_input_tokens", 0)
            usage_total["output_tokens"] += usage.get("output_tokens", 0)

            if not model_used and msg.get("model"):
                model_used = msg.get("model")

            # Context fill rate
            cumulative_input += input_tok
            if input_tok > 0:
                context_points.append([msg_index, cumulative_input])

            # Parse tool_use blocks
            content = msg.get("content", [])
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "tool_use":
                        tool_name = block.get("name", "unknown")
                        tool_id = block.get("id", "")
                        pending_tool_uses[tool_id] = tool_name
                        tool_calls_total += 1

                        # Detect Skill tool invocations
                        if tool_name == "Skill":
                            inp = block.get("input", {})
                            skill_name = inp.get("skill", "")
                            if skill_name:
                                skills.append(skill_name)

            msg_index += 1

        elif msg_type == "user":
            user_type = obj.get("userType", "")
            is_sidechain = obj.get("isSidechain", False)
            content = obj.get("message", {}).get("content", "")

            # Check for tool_result blocks
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "tool_result":
                        tool_id = block.get("tool_use_id", "")
                        tool_name = pending_tool_uses.pop(tool_id, "unknown")
                        is_error = block.get("is_error", False)
                        result_content = extract_text_content(block.get("content", ""))

                        if is_error or re.search(r"\b(Error|error|failed|FAILED)\b", result_content[:500]):
                            tool_results[tool_name]["failure"] += 1
                            last_was_tool_error = True
                        else:
                            tool_results[tool_name]["success"] += 1
                            last_was_tool_error = False

            text = extract_text_content(content)

            if text and not is_sidechain and is_human_prompt(obj) and user_type != "tool":
                # HIR: intervention after tool error
                if last_was_tool_error:
                    intervention_prompts += 1
                last_was_tool_error = False

                prompts.append({"text": text, "timestamp": obj.get("timestamp")})
                human_texts.append(text)

                # Command detection
                cmd_match = COMMAND_PATTERN.match(text.strip())
                if cmd_match:
                    commands.append(cmd_match.group(0))

                # Frustration: keyword check
                human_idx = len(human_texts) - 1
                if FRUSTRATION_KEYWORDS.search(text):
                    frustration_score += 1
                    last_frustration_msg_idx = human_idx

                # Frustration: repeated prompt (similarity > 0.8 within window of 3)
                if human_idx >= 1:
                    for prev_idx in range(max(0, human_idx - 2), human_idx):
                        if similarity_ratio(human_texts[prev_idx], text) > 0.8:
                            frustration_score += 2
                            last_frustration_msg_idx = human_idx
                            break

            msg_index += 1

    # Frustration: +3 if session ends within 2 msgs after frustration signal
    total_human = len(human_texts)
    if last_frustration_msg_idx >= 0 and (total_human - last_frustration_msg_idx) <= 2:
        frustration_score += 3

    frustration_score = min(frustration_score, 10)

    # Frustration triggers for hotspots
    frustration_triggers = []
    if frustration_score > 0:
        for i, text in enumerate(human_texts):
            if FRUSTRATION_KEYWORDS.search(text):
                match = FRUSTRATION_KEYWORDS.search(text)
                frustration_triggers.append(f"keyword: {match.group()}")
            if i >= 1:
                for prev_idx in range(max(0, i - 2), i):
                    if similarity_ratio(human_texts[prev_idx], text) > 0.8:
                        frustration_triggers.append(f"repeated prompt x{i - prev_idx + 1}")
                        break
        if last_frustration_msg_idx >= 0 and (total_human - last_frustration_msg_idx) <= 2:
            frustration_triggers.append("early session end after frustration")

    # Subagent sessions
    session_dir = jsonl_path.parent / jsonl_path.stem
    if session_dir.is_dir():
        subagents_dir = session_dir / "subagents"
        if subagents_dir.is_dir():
            for sub_file in subagents_dir.glob("*.jsonl"):
                try:
                    sub_usage = defaultdict(int)
                    with open(sub_file) as sf:
                        for sline in sf:
                            try:
                                sobj = json.loads(sline)
                                if sobj.get("type") == "assistant":
                                    su = sobj.get("message", {}).get("usage", {})
                                    for k in PRICING:
                                        sub_usage[k] += su.get(k, 0)
                            except json.JSONDecodeError:
                                continue
                    sub_total = sum(sub_usage.values())
                    if sub_total > 0:
                        subagent_tokens += sub_total
                        subagent_count += 1
                except Exception:
                    continue

    total_tokens = sum(usage_total.values())

    # HIR
    hir = intervention_prompts / tool_calls_total if tool_calls_total > 0 else 0.0

    # Tool precision
    total_success = sum(v["success"] for v in tool_results.values())
    total_failure = sum(v["failure"] for v in tool_results.values())
    tool_precision_overall = total_success / (total_success + total_failure) if (total_success + total_failure) > 0 else 0.0

    tool_precision_by_tool = {}
    for tname, counts in tool_results.items():
        total = counts["success"] + counts["failure"]
        if total > 0:
            tool_precision_by_tool[tname] = round(counts["success"] / total, 3)

    # Subagent ratio
    subagent_ratio = subagent_tokens / total_tokens if total_tokens > 0 else 0.0

    first_prompt = prompts[0]["text"][:200].replace("\n", " ") if prompts else ""
    session_date = timestamp_start[:10] if timestamp_start else ""

    return {
        "session_id": session_id or jsonl_path.stem,
        "timestamp_start": timestamp_start,
        "timestamp_end": timestamp_end,
        "date": session_date,
        "model": model_used,
        "usage": dict(usage_total),
        "total_tokens": total_tokens,
        "cost": round(calculate_cost(dict(usage_total)), 4),
        "hir": round(hir, 4),
        "frustration": frustration_score,
        "frustration_triggers": frustration_triggers,
        "tool_precision": round(tool_precision_overall, 4),
        "tool_precision_by_tool": tool_precision_by_tool,
        "tool_calls_total": tool_calls_total,
        "context_points": context_points,
        "commands": commands,
        "skills": skills,
        "subagent_tokens": subagent_tokens,
        "subagent_count": subagent_count,
        "subagent_ratio": round(subagent_ratio, 4),
        "first_prompt": first_prompt,
        "prompts_count": len(prompts),
    }


# ── Data aggregation ──


def build_data(all_sessions):
    """Build the data.json structure from all parsed sessions."""
    cutoff = get_cutoff()
    range_label = f"last {SINCE_DAYS} days" if SINCE_DAYS else (f"since {SINCE_DATE}" if SINCE_DATE else "all time")

    sessions = [(pn, dom, dn, s) for pn, dom, dn, s in all_sessions
                if session_in_range(s["timestamp_start"], cutoff) and s["total_tokens"] > 0]

    total_cost = sum(s["cost"] for _, _, _, s in sessions)
    total_tokens = sum(s["total_tokens"] for _, _, _, s in sessions)
    total_sessions = len(sessions)
    n = max(total_sessions, 1)

    summary = {
        "total_cost_usd": round(total_cost, 2),
        "total_sessions": total_sessions,
        "total_tokens": total_tokens,
        "avg_hir": round(sum(s["hir"] for _, _, _, s in sessions) / n, 4),
        "avg_frustration": round(sum(s["frustration"] for _, _, _, s in sessions) / n, 2),
        "avg_tool_precision": round(sum(s["tool_precision"] for _, _, _, s in sessions) / n, 4),
        "total_subagent_sessions": sum(1 for _, _, _, s in sessions if s["subagent_count"] > 0),
        "total_commands_used": sum(len(s["commands"]) + len(s["skills"]) for _, _, _, s in sessions),
    }

    # Daily aggregation
    daily_agg = defaultdict(lambda: {"sessions": 0, "tokens": 0, "cost": 0.0, "hir_sum": 0.0, "frust_sum": 0.0})
    for _, _, _, s in sessions:
        day = s["date"]
        if day:
            daily_agg[day]["sessions"] += 1
            daily_agg[day]["tokens"] += s["total_tokens"]
            daily_agg[day]["cost"] += s["cost"]
            daily_agg[day]["hir_sum"] += s["hir"]
            daily_agg[day]["frust_sum"] += s["frustration"]

    daily = []
    for day in sorted(daily_agg.keys()):
        d = daily_agg[day]
        dn = max(d["sessions"], 1)
        daily.append({
            "date": day, "sessions": d["sessions"], "tokens": d["tokens"],
            "cost": round(d["cost"], 2), "hir": round(d["hir_sum"] / dn, 4),
            "frustration": round(d["frust_sum"] / dn, 2),
        })

    # Domain aggregation
    domain_agg = defaultdict(lambda: {"sessions": 0, "tokens": 0, "cost": 0.0, "hir_sum": 0.0, "subagent_tokens": 0, "total_tokens_for_ratio": 0})
    for _, domain, _, s in sessions:
        domain_agg[domain]["sessions"] += 1
        domain_agg[domain]["tokens"] += s["total_tokens"]
        domain_agg[domain]["cost"] += s["cost"]
        domain_agg[domain]["hir_sum"] += s["hir"]
        domain_agg[domain]["subagent_tokens"] += s["subagent_tokens"]
        domain_agg[domain]["total_tokens_for_ratio"] += s["total_tokens"]

    domains = []
    for dname in sorted(domain_agg.keys(), key=lambda k: domain_agg[k]["cost"], reverse=True):
        d = domain_agg[dname]
        dn = max(d["sessions"], 1)
        sr = d["subagent_tokens"] / max(d["total_tokens_for_ratio"], 1)
        domains.append({"name": dname, "sessions": d["sessions"], "tokens": d["tokens"],
                        "cost": round(d["cost"], 2), "hir": round(d["hir_sum"] / dn, 4),
                        "subagent_ratio": round(sr, 4)})

    # Project aggregation
    project_agg = defaultdict(lambda: {"domain": "", "sessions": 0, "tokens": 0, "cost": 0.0})
    for project_name, domain, _, s in sessions:
        project_agg[project_name]["domain"] = domain
        project_agg[project_name]["sessions"] += 1
        project_agg[project_name]["tokens"] += s["total_tokens"]
        project_agg[project_name]["cost"] += s["cost"]

    projects = [{"name": pn, "domain": p["domain"], "sessions": p["sessions"],
                 "tokens": p["tokens"], "cost": round(p["cost"], 2)}
                for pn, p in sorted(project_agg.items(), key=lambda x: x[1]["cost"], reverse=True)]

    # Costly sessions (top 25)
    sorted_by_cost = sorted(sessions, key=lambda x: x[3]["cost"], reverse=True)[:25]
    costly_sessions = [{"id": s["session_id"], "project": pn, "domain": dom, "cost": s["cost"],
                        "tokens": s["total_tokens"], "hir": s["hir"], "frustration": s["frustration"],
                        "first_prompt": s["first_prompt"], "date": s["date"]}
                       for pn, dom, _, s in sorted_by_cost]

    # Command frequency
    cmd_counter = Counter()
    for _, _, _, s in sessions:
        for cmd in s["commands"]:
            cmd_counter[cmd] += 1
        for skill in s["skills"]:
            cmd_counter[f"/{skill}"] += 1
    command_frequency = dict(cmd_counter.most_common(50))

    # Tool precision aggregated
    tool_precision_by_name = defaultdict(list)
    precision_weighted_sum = 0.0
    precision_weight_total = 0
    for _, _, _, s in sessions:
        if s["tool_calls_total"] > 0:
            precision_weighted_sum += s["tool_precision"] * s["tool_calls_total"]
            precision_weight_total += s["tool_calls_total"]
        for tname, prec in s["tool_precision_by_tool"].items():
            tool_precision_by_name[tname].append(prec)

    overall_precision = precision_weighted_sum / max(precision_weight_total, 1)
    by_tool = {tname: round(sum(precs) / len(precs), 3) for tname, precs in tool_precision_by_name.items()}
    tool_precision = {"overall": round(overall_precision, 4), "by_tool": by_tool}

    # Context fills (top 10 longest)
    sessions_with_context = [(pn, s) for pn, _, _, s in sessions if len(s["context_points"]) > 10]
    sessions_with_context.sort(key=lambda x: len(x[1]["context_points"]), reverse=True)
    context_fills = [{"session_id": s["session_id"], "project": pn, "points": s["context_points"]}
                     for pn, s in sessions_with_context[:10]]

    # Heatmap: date x hour -> tokens
    heatmap = defaultdict(lambda: defaultdict(int))
    for _, _, _, s in sessions:
        if s["timestamp_start"]:
            try:
                ts = datetime.fromisoformat(s["timestamp_start"].replace("Z", "+00:00"))
                day = ts.strftime("%Y-%m-%d")
                hour = ts.strftime("%H")
                heatmap[day][hour] += s["total_tokens"]
            except (ValueError, AttributeError):
                pass

    # Frustration hotspots (score > 5)
    frustration_hotspots = sorted(
        [{"session_id": s["session_id"], "project": pn, "score": s["frustration"],
          "triggers": s["frustration_triggers"][:5], "date": s["date"]}
         for pn, _, _, s in sessions if s["frustration"] > 5],
        key=lambda x: x["score"], reverse=True)

    return {
        "generated": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
        "range": range_label,
        "total_projects_scanned": len(set(pn for pn, _, _, _ in sessions)),
        "summary": summary,
        "daily": daily,
        "domains": domains,
        "projects": projects,
        "costly_sessions": costly_sessions,
        "command_frequency": command_frequency,
        "tool_precision": tool_precision,
        "context_fills": context_fills,
        "heatmap": {day: dict(hours) for day, hours in sorted(heatmap.items())},
        "frustration_hotspots": frustration_hotspots,
    }


# ── HTML injection for file:// compatibility ──

EMBED_START = '<!-- ANALYTICS_DATA_START -->'
EMBED_END = '<!-- ANALYTICS_DATA_END -->'


def inject_data_into_html(html_path, json_str):
    """Inject JSON data into the dashboard HTML as window.__ANALYTICS_DATA__."""
    html = html_path.read_text()
    safe_json = json_str.replace('</', '<\\/')
    script_block = f'{EMBED_START}\n<script>window.__ANALYTICS_DATA__ = {safe_json};</script>\n{EMBED_END}'

    if EMBED_START in html:
        start = html.index(EMBED_START)
        end = html.index(EMBED_END) + len(EMBED_END)
        html = html[:start] + script_block + html[end:]
    else:
        html = html.replace('</head>', f'{script_block}\n</head>')

    html_path.write_text(html)


# ── Main ──


def get_output_dir():
    if VAULT_PATH:
        return Path(VAULT_PATH) / "00-Dashboard"
    return Path("00-Dashboard")


def main():
    print("Scanning projects...", file=sys.stderr)
    all_sessions = []

    if not PROJECTS_DIR.is_dir():
        print(f"Error: {PROJECTS_DIR} not found", file=sys.stderr)
        sys.exit(1)

    project_count = 0
    for project_dir in sorted(PROJECTS_DIR.iterdir()):
        if not project_dir.is_dir():
            continue
        project_count += 1
        project_name = get_project_name(project_dir.name)
        domain = get_domain(project_dir.name)

        for jsonl_file in sorted(project_dir.glob("*.jsonl")):
            session = parse_session_full(jsonl_file)
            if session:
                all_sessions.append((project_name, domain, project_dir.name, session))

    print(f"Found {project_count} projects, {len(all_sessions)} sessions", file=sys.stderr)

    data = build_data(all_sessions)
    data["total_projects_scanned"] = project_count

    output_json = json.dumps(data, indent=2, ensure_ascii=False)

    if "--stdout" in sys.argv:
        print(output_json)
    else:
        output_dir = get_output_dir()
        output_dir.mkdir(parents=True, exist_ok=True)
        output_path = output_dir / "data.json"
        with open(output_path, "w") as f:
            f.write(output_json)
        print(f"Written: {output_path}", file=sys.stderr)

        # Embed data into HTML for file:// compatibility
        for html_name in ["analytics.html", "dashboard.html"]:
            html_path = output_dir / html_name
            if html_path.exists():
                inject_data_into_html(html_path, output_json)
                print(f"Embedded data into: {html_path}", file=sys.stderr)

        s = data["summary"]
        print(f"\nSummary:", file=sys.stderr)
        print(f"  Cost: ${s['total_cost_usd']:.2f}", file=sys.stderr)
        print(f"  Sessions: {s['total_sessions']}", file=sys.stderr)
        print(f"  Tokens: {s['total_tokens']:,}", file=sys.stderr)
        print(f"  Avg HIR: {s['avg_hir']:.3f}", file=sys.stderr)
        print(f"  Avg Frustration: {s['avg_frustration']:.1f}", file=sys.stderr)
        print(f"  Tool Precision: {s['avg_tool_precision']:.3f}", file=sys.stderr)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Open Arcana integrity validator.

Walks the repository and compares filesystem reality against ARCHITECTURE.md.
Flags drift between what the master doc claims and what the repo actually contains.

Usage:
    python3 tools/arcana-integrity.py            # human-readable
    python3 tools/arcana-integrity.py --json     # machine-readable
    python3 tools/arcana-integrity.py --inventory  # just print inventory counts

Exit codes:
    0 = no ERRORs (WARNs allowed)
    1 = at least one ERROR
    2 = internal/script error

Stdlib only. Runs on Python 3.9+.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parent.parent
ARCH_DOC = REPO_ROOT / "ARCHITECTURE.md"
CHANGELOG = REPO_ROOT / "CHANGELOG.md"
SETUP_SH = REPO_ROOT / "setup.sh"

SEVERITY_ORDER = {"ERROR": 0, "WARN": 1, "INFO": 2}


@dataclass
class Finding:
    severity: str  # ERROR, WARN, INFO
    check: str
    message: str
    path: str | None = None
    expected: str | None = None
    actual: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {k: v for k, v in asdict(self).items() if v is not None}


@dataclass
class Report:
    findings: list[Finding] = field(default_factory=list)
    inventory: dict[str, Any] = field(default_factory=dict)

    def add(self, f: Finding) -> None:
        self.findings.append(f)

    def error_count(self) -> int:
        return sum(1 for f in self.findings if f.severity == "ERROR")

    def warn_count(self) -> int:
        return sum(1 for f in self.findings if f.severity == "WARN")

    def info_count(self) -> int:
        return sum(1 for f in self.findings if f.severity == "INFO")


# ---------------------------------------------------------------------------
# Filesystem inventory
# ---------------------------------------------------------------------------

def collect_inventory() -> dict[str, Any]:
    """Walk the filesystem and return a structured inventory."""
    inv: dict[str, Any] = {}

    # Core
    inv["core_rules"] = sorted(p.name for p in (REPO_ROOT / "core/rules").glob("*.md"))
    inv["core_hooks"] = sorted(p.name for p in (REPO_ROOT / "core/hooks").glob("*.sh"))
    memory_dir = REPO_ROOT / "core/memory"
    inv["core_memory"] = sorted(p.name for p in memory_dir.iterdir()) if memory_dir.exists() else []

    # Modules (list of top-level directories under modules/)
    modules_dir = REPO_ROOT / "modules"
    inv["modules"] = sorted(p.name for p in modules_dir.iterdir() if p.is_dir())

    # Per-module asset counts
    inv["module_assets"] = {}
    for mod_name in inv["modules"]:
        mod_path = modules_dir / mod_name
        assets: dict[str, list[str]] = {
            "hooks": [],
            "rules": [],
            "commands": [],
            "templates": [],
            "tools": [],
            "dashboard": [],
            "examples": [],
        }
        for sub, pattern in [
            ("hooks", "hooks/*.sh"),
            ("rules", "rules/*.md"),
            ("commands", "commands/*.md"),
            ("templates", "templates/*.md"),
            ("tools", "tools/*.py"),
            ("dashboard", "dashboard/*"),
            ("examples", "examples/*.md"),
        ]:
            assets[sub] = sorted(p.name for p in mod_path.glob(pattern))
        # Include rule templates (.md.template)
        assets["rule_templates"] = sorted(
            p.name for p in mod_path.glob("rules/*.md.template")
        )
        inv["module_assets"][mod_name] = assets

    # Top-level tools
    tools_dir = REPO_ROOT / "tools"
    inv["top_level_tools"] = sorted(p.name for p in tools_dir.glob("*.py")) if tools_dir.exists() else []

    # Docs
    docs_dir = REPO_ROOT / "docs"
    inv["docs"] = sorted(p.name for p in docs_dir.glob("*.md")) if docs_dir.exists() else []

    # Examples (presets)
    ex_dir = REPO_ROOT / "examples"
    inv["examples"] = sorted(p.name for p in ex_dir.iterdir() if p.is_dir()) if ex_dir.exists() else []

    return inv


# ---------------------------------------------------------------------------
# Individual checks
# ---------------------------------------------------------------------------

def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""


def check_arch_doc_present(report: Report) -> None:
    """ARCHITECTURE.md must exist at repo root."""
    if not ARCH_DOC.exists():
        report.add(Finding(
            severity="ERROR",
            check="arch-doc-present",
            message="ARCHITECTURE.md is missing at repo root",
            path=str(ARCH_DOC.relative_to(REPO_ROOT)),
        ))


def check_rule_counts(report: Report, inv: dict[str, Any]) -> None:
    """
    For each rule file that uses numbered rules (AS-N, TE-N, CT-N, CSR-N),
    count the actual numbered headings and compare against the count claimed
    in ARCHITECTURE.md.
    """
    rule_files = {
        "anti-sycophancy": (
            REPO_ROOT / "modules/anti-sycophancy/rules/anti-sycophancy.md",
            r"^###?\s+AS-(\d+)",
        ),
        "token-efficiency": (
            REPO_ROOT / "modules/token-efficiency/rules/token-efficiency.md",
            r"TE-(\d+)",
        ),
        "completion-tracking": (
            REPO_ROOT / "modules/completion-tracking/rules/completion-tracking.md",
            r"^###?\s+CT-(\d+)",
        ),
        "cross-source-reconciler": (
            REPO_ROOT / "modules/completion-tracking/rules/cross-source-reconciler.md",
            r"^###?\s+CSR-(\d+)",
        ),
    }

    arch_text = read_text(ARCH_DOC)
    counts_found: dict[str, int] = {}

    for name, (path, pattern) in rule_files.items():
        if not path.exists():
            report.add(Finding(
                severity="WARN",
                check="rule-file-missing",
                message=f"Rule file for {name} missing",
                path=str(path.relative_to(REPO_ROOT)),
            ))
            continue

        text = read_text(path)
        matches = set(re.findall(pattern, text, flags=re.MULTILINE))
        count = len(matches)
        counts_found[name] = count

    # Pull claimed counts from ARCHITECTURE.md. We look for exact strings.
    claims = {
        "anti-sycophancy": re.search(r"AS-1 through AS-(\d+)", arch_text),
        "token-efficiency": re.search(r"TE-1 through TE-(\d+)", arch_text),
        "completion-tracking": re.search(r"CT-1, CT-2, CT-(\d+)", arch_text),
        "cross-source-reconciler": re.search(r"CSR-1, CSR-2, CSR-(\d+)", arch_text),
    }

    for name, match in claims.items():
        actual = counts_found.get(name)
        if match is None:
            report.add(Finding(
                severity="WARN",
                check="rule-count-claim-missing",
                message=f"ARCHITECTURE.md does not mention a count for {name}",
            ))
            continue
        claimed = int(match.group(1))
        if actual is None:
            continue  # already warned
        if actual != claimed:
            report.add(Finding(
                severity="ERROR",
                check="rule-count-drift",
                message=f"{name}: ARCHITECTURE.md claims {claimed} rules, filesystem has {actual}",
                expected=str(claimed),
                actual=str(actual),
            ))

    report.inventory.setdefault("rule_counts", counts_found)


def check_hook_inventory(report: Report, inv: dict[str, Any]) -> None:
    """Every .sh file under core/hooks/ and modules/*/hooks/ must appear in ARCHITECTURE.md § Hooks."""
    arch_text = read_text(ARCH_DOC)
    # Extract just the "## Hooks" section up to next "## "
    hooks_section_match = re.search(
        r"^## Hooks\s*$(.*?)(?=^## )",
        arch_text,
        flags=re.MULTILINE | re.DOTALL,
    )
    if not hooks_section_match:
        report.add(Finding(
            severity="ERROR",
            check="arch-hooks-section-missing",
            message="ARCHITECTURE.md is missing the ## Hooks section",
        ))
        return

    hooks_section = hooks_section_match.group(1)

    all_hooks: list[tuple[str, str]] = []  # (hook_filename, source_module)
    for name in inv["core_hooks"]:
        all_hooks.append((name, "core"))
    for mod in inv["modules"]:
        for hook in inv["module_assets"][mod]["hooks"]:
            all_hooks.append((hook, mod))

    for hook_name, source in all_hooks:
        # Look for the bare filename inside a backtick in the hooks section
        if f"`{hook_name}`" not in hooks_section:
            report.add(Finding(
                severity="ERROR",
                check="hook-undocumented",
                message=f"Hook {hook_name} (from {source}) not listed in ARCHITECTURE.md § Hooks",
                path=f"{source}/hooks/{hook_name}" if source != "core" else f"core/hooks/{hook_name}",
            ))


def check_command_inventory(report: Report, inv: dict[str, Any]) -> None:
    """Every .md under modules/commands/commands/ must appear in ARCHITECTURE.md § Slash commands."""
    arch_text = read_text(ARCH_DOC)
    commands_section_match = re.search(
        r"^## Slash commands\s*$(.*?)(?=^## )",
        arch_text,
        flags=re.MULTILINE | re.DOTALL,
    )
    if not commands_section_match:
        report.add(Finding(
            severity="ERROR",
            check="arch-commands-section-missing",
            message="ARCHITECTURE.md is missing the ## Slash commands section",
        ))
        return
    commands_section = commands_section_match.group(1)

    all_commands = inv["module_assets"].get("commands", {}).get("commands", [])
    # The module is literally named "commands" and its commands live inside commands/commands/
    # We already collected them as module_assets["commands"]["commands"]

    for cmd_file in all_commands:
        cmd_name = cmd_file.replace(".md", "")
        # Either as `/cmd-name` or as `cmd-file.md` reference
        if f"/{cmd_name}" not in commands_section and f"`{cmd_file}`" not in commands_section:
            report.add(Finding(
                severity="ERROR",
                check="command-undocumented",
                message=f"Command /{cmd_name} (file {cmd_file}) not listed in ARCHITECTURE.md § Slash commands",
                path=f"modules/commands/commands/{cmd_file}",
            ))


def check_module_inventory(report: Report, inv: dict[str, Any]) -> None:
    """Every directory under modules/ must appear in ARCHITECTURE.md § Modules."""
    arch_text = read_text(ARCH_DOC)
    modules_section_match = re.search(
        r"^## Modules\s*$(.*?)(?=^## )",
        arch_text,
        flags=re.MULTILINE | re.DOTALL,
    )
    if not modules_section_match:
        report.add(Finding(
            severity="ERROR",
            check="arch-modules-section-missing",
            message="ARCHITECTURE.md is missing the ## Modules section",
        ))
        return
    modules_section = modules_section_match.group(1)

    for mod in inv["modules"]:
        if f"`{mod}`" not in modules_section:
            report.add(Finding(
                severity="ERROR",
                check="module-undocumented",
                message=f"Module {mod} not listed in ARCHITECTURE.md § Modules",
                path=f"modules/{mod}",
            ))

    # Check module count claim (from Repository layout)
    claim_match = re.search(r"(\d+) optional modules", arch_text)
    if claim_match:
        claimed = int(claim_match.group(1))
        actual = len(inv["modules"])
        if claimed != actual:
            report.add(Finding(
                severity="ERROR",
                check="module-count-drift",
                message=f"ARCHITECTURE.md claims {claimed} modules, filesystem has {actual}",
                expected=str(claimed),
                actual=str(actual),
            ))


def check_version_parity(report: Report) -> None:
    """setup.sh VERSION= must match the latest ## [X.Y.Z] heading in CHANGELOG.md."""
    setup_text = read_text(SETUP_SH)
    changelog_text = read_text(CHANGELOG)

    setup_match = re.search(r'^VERSION="([^"]+)"', setup_text, flags=re.MULTILINE)
    if not setup_match:
        report.add(Finding(
            severity="WARN",
            check="setup-version-unparseable",
            message="Could not find VERSION= in setup.sh",
        ))
        return
    setup_version = setup_match.group(1).strip()

    changelog_match = re.search(r"^## \[(\d+\.\d+\.\d+)\]", changelog_text, flags=re.MULTILINE)
    if not changelog_match:
        report.add(Finding(
            severity="WARN",
            check="changelog-first-entry-unparseable",
            message="Could not find a version heading in CHANGELOG.md",
        ))
        return
    changelog_version = changelog_match.group(1).strip()

    if setup_version != changelog_version:
        report.add(Finding(
            severity="ERROR",
            check="version-parity",
            message=f"setup.sh VERSION ({setup_version}) does not match latest CHANGELOG entry ({changelog_version})",
            expected=changelog_version,
            actual=setup_version,
        ))

    report.inventory["setup_version"] = setup_version
    report.inventory["changelog_latest"] = changelog_version


def check_git_tags(report: Report) -> None:
    """Every minor/major ## [X.Y.Z] heading in CHANGELOG.md must have a matching git tag."""
    changelog_text = read_text(CHANGELOG)
    versions = re.findall(r"^## \[(\d+\.\d+\.\d+)\]", changelog_text, flags=re.MULTILINE)

    try:
        result = subprocess.run(
            ["git", "tag"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=10,
        )
        tags = set(result.stdout.split())
    except (subprocess.TimeoutExpired, FileNotFoundError):
        report.add(Finding(
            severity="WARN",
            check="git-tags-unavailable",
            message="Could not run `git tag` to verify tag parity",
        ))
        return

    missing = []
    for v in versions:
        tag = f"v{v}"
        if tag not in tags:
            missing.append(tag)

    if missing:
        report.add(Finding(
            severity="WARN",
            check="git-tag-drift",
            message=f"CHANGELOG entries missing matching git tags: {', '.join(missing)}",
            actual=",".join(missing),
        ))

    report.inventory["git_tags"] = sorted(tags)


def check_orphan_files(report: Report, inv: dict[str, Any]) -> None:
    """Files in hooks/ or commands/ directories that are not .sh/.md (and not build artifacts) flag as orphan."""
    for base in [REPO_ROOT / "core/hooks", REPO_ROOT / "core/rules"]:
        if not base.exists():
            continue
        for p in base.iterdir():
            if p.is_file() and not (p.suffix in {".sh", ".md"} or p.name.startswith(".")):
                report.add(Finding(
                    severity="INFO",
                    check="orphan-file",
                    message=f"Unexpected file type in {base.name}: {p.name}",
                    path=str(p.relative_to(REPO_ROOT)),
                ))


def check_broken_refs(report: Report) -> None:
    """Find relative paths referenced in ARCHITECTURE.md and verify they exist."""
    arch_text = read_text(ARCH_DOC)
    # Match tokens like `modules/commands/commands/*.md` or explicit paths in backticks
    path_pattern = r"`((?:modules|core|tools|docs|examples)/[^`\s]+)`"
    refs = set(re.findall(path_pattern, arch_text))

    for ref in refs:
        # Skip placeholder paths like modules/<name>/ or examples/<preset>/
        if "<" in ref or ">" in ref:
            continue
        # Skip glob patterns and unknown wildcards
        if "*" in ref or "**" in ref:
            # Check that the directory containing the glob exists
            dir_part = ref.split("/*")[0].split("/**")[0]
            if not (REPO_ROOT / dir_part).exists():
                report.add(Finding(
                    severity="WARN",
                    check="broken-glob-base",
                    message=f"Path pattern in ARCHITECTURE.md points to non-existent base: {ref}",
                    path=ref,
                ))
            continue

        full = REPO_ROOT / ref
        if not full.exists():
            report.add(Finding(
                severity="WARN",
                check="broken-path-ref",
                message=f"ARCHITECTURE.md references a path that does not exist: {ref}",
                path=ref,
            ))


def check_template_vars(report: Report) -> None:
    """
    Check that every {{VAR}} token used in hooks or commands (in modules/) is
    documented in ARCHITECTURE.md § Template variables.
    """
    arch_text = read_text(ARCH_DOC)
    vars_section_match = re.search(
        r"^## Template variables\s*$(.*?)(?=^## )",
        arch_text,
        flags=re.MULTILINE | re.DOTALL,
    )
    if not vars_section_match:
        report.add(Finding(
            severity="WARN",
            check="arch-vars-section-missing",
            message="ARCHITECTURE.md lacks ## Template variables section",
        ))
        return

    vars_section = vars_section_match.group(1)
    documented = set(re.findall(r"\{\{([A-Z_]+)\}\}", vars_section))

    # Find all {{VAR}} usages in hook/command/rule files inside modules/ and core/
    used: dict[str, list[str]] = {}
    for root in [REPO_ROOT / "core", REPO_ROOT / "modules"]:
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            if path.suffix not in {".sh", ".md", ".template", ".json", ".yaml"} and ".template" not in path.name:
                continue
            text = read_text(path)
            for m in re.finditer(r"\{\{([A-Z_]+)\}\}", text):
                used.setdefault(m.group(1), []).append(str(path.relative_to(REPO_ROOT)))

    for var, paths in used.items():
        if var not in documented:
            report.add(Finding(
                severity="WARN",
                check="undocumented-template-var",
                message=f"Template variable {{{{{var}}}}} used in code but not documented in ARCHITECTURE.md § Template variables",
                path=paths[0],
                actual=f"used in {len(paths)} file(s)",
            ))

    report.inventory["template_vars_documented"] = sorted(documented)
    report.inventory["template_vars_used"] = sorted(used.keys())


def check_changelog_stale(report: Report) -> None:
    """Warn if CHANGELOG.md has not been touched in > 90 days."""
    if not CHANGELOG.exists():
        report.add(Finding(
            severity="ERROR",
            check="changelog-missing",
            message="CHANGELOG.md is missing at repo root",
        ))
        return

    import time
    mtime = CHANGELOG.stat().st_mtime
    age_days = (time.time() - mtime) / 86400
    if age_days > 90:
        report.add(Finding(
            severity="INFO",
            check="changelog-stale",
            message=f"CHANGELOG.md has not been updated in {age_days:.0f} days",
        ))


def check_readme_drift(report: Report, inv: dict[str, Any]) -> None:
    """
    README.md headline claims should not contradict ARCHITECTURE.md.
    Specifically: hook count, command count, module count.
    """
    readme = read_text(REPO_ROOT / "README.md")
    if not readme:
        return

    # Extract simple claims
    claims = re.findall(r"(\d+)\s+(hooks|commands|note templates|modules)", readme)

    # Unique command count: scripts-offload commands OVERRIDE (same filename)
    # rather than ADD to the commands module. Count unique files only.
    command_names = set()
    for mod in ("commands", "analytics", "scripts-offload"):
        for cmd in inv["module_assets"].get(mod, {}).get("commands", []):
            command_names.add(cmd)

    real = {
        "hooks": len(inv["core_hooks"])
        + sum(len(a["hooks"]) for a in inv["module_assets"].values()),
        "commands": len(command_names),
        "note templates": len(inv["module_assets"].get("vault-structure", {}).get("templates", [])),
        "modules": len(inv["modules"]),
    }

    for count_str, category in claims:
        count = int(count_str)
        if category in real and count != real[category]:
            report.add(Finding(
                severity="WARN",
                check="readme-count-drift",
                message=f"README.md claims {count} {category}, filesystem has {real[category]}",
                path="README.md",
                expected=str(real[category]),
                actual=count_str,
            ))


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

def run_all_checks(report: Report) -> None:
    inv = collect_inventory()
    report.inventory.update({
        "core_rules_count": len(inv["core_rules"]),
        "core_hooks_count": len(inv["core_hooks"]),
        "modules_count": len(inv["modules"]),
        "module_names": inv["modules"],
        "top_level_tools_count": len(inv["top_level_tools"]),
        "top_level_tools": inv["top_level_tools"],
        "docs_count": len(inv["docs"]),
        "examples_presets": inv["examples"],
    })

    check_arch_doc_present(report)
    if not (REPO_ROOT / "ARCHITECTURE.md").exists():
        # Can't do doc-dependent checks
        return

    check_rule_counts(report, inv)
    check_hook_inventory(report, inv)
    check_command_inventory(report, inv)
    check_module_inventory(report, inv)
    check_version_parity(report)
    check_git_tags(report)
    check_orphan_files(report, inv)
    check_broken_refs(report)
    check_template_vars(report)
    check_changelog_stale(report)
    check_readme_drift(report, inv)


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def format_human(report: Report) -> str:
    lines = []
    lines.append("=" * 70)
    lines.append("  Open Arcana Integrity Check")
    lines.append("=" * 70)
    lines.append("")

    inv = report.inventory
    lines.append("Inventory:")
    lines.append(f"  core_rules:        {inv.get('core_rules_count', '?')}")
    lines.append(f"  core_hooks:        {inv.get('core_hooks_count', '?')}")
    lines.append(f"  modules:           {inv.get('modules_count', '?')}")
    lines.append(f"  top_level_tools:   {inv.get('top_level_tools_count', '?')}")
    lines.append(f"  docs:              {inv.get('docs_count', '?')}")
    lines.append(f"  setup_version:     {inv.get('setup_version', '?')}")
    lines.append(f"  changelog_latest:  {inv.get('changelog_latest', '?')}")
    lines.append("")

    by_sev: dict[str, list[Finding]] = {"ERROR": [], "WARN": [], "INFO": []}
    for f in report.findings:
        by_sev.setdefault(f.severity, []).append(f)

    for sev in ["ERROR", "WARN", "INFO"]:
        items = by_sev.get(sev, [])
        if not items:
            continue
        lines.append(f"{sev} ({len(items)}):")
        for f in items:
            prefix = f"  [{f.check}]"
            body = f.message
            if f.path:
                body += f" ({f.path})"
            if f.expected is not None and f.actual is not None:
                body += f" expected={f.expected}, actual={f.actual}"
            lines.append(f"{prefix} {body}")
        lines.append("")

    # Summary
    e = report.error_count()
    w = report.warn_count()
    i = report.info_count()
    lines.append("-" * 70)
    if e == 0 and w == 0 and i == 0:
        lines.append("  All checks passed.")
    else:
        lines.append(f"  Summary: {e} ERROR, {w} WARN, {i} INFO")
    lines.append("=" * 70)
    return "\n".join(lines)


def format_inventory(report: Report) -> str:
    return json.dumps(report.inventory, indent=2, sort_keys=True)


def format_json(report: Report) -> str:
    out = {
        "inventory": report.inventory,
        "findings": [f.to_dict() for f in report.findings],
        "summary": {
            "errors": report.error_count(),
            "warns": report.warn_count(),
            "infos": report.info_count(),
        },
    }
    return json.dumps(out, indent=2, sort_keys=True)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Open Arcana integrity validator")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON output")
    parser.add_argument("--inventory", action="store_true", help="Print the inventory only, skip drift checks")
    parser.add_argument("--fail-on-warn", action="store_true", help="Exit non-zero on WARN as well as ERROR")
    args = parser.parse_args(argv)

    report = Report()

    if args.inventory:
        # Just run inventory, skip checks
        inv = collect_inventory()
        report.inventory.update({
            "core_rules": inv["core_rules"],
            "core_hooks": inv["core_hooks"],
            "modules": inv["modules"],
            "module_assets": inv["module_assets"],
            "top_level_tools": inv["top_level_tools"],
            "docs": inv["docs"],
            "examples": inv["examples"],
        })
        print(format_inventory(report))
        return 0

    try:
        run_all_checks(report)
    except Exception as e:
        print(f"arcana-integrity: internal error: {e}", file=sys.stderr)
        return 2

    if args.json:
        print(format_json(report))
    else:
        print(format_human(report))

    if report.error_count() > 0:
        return 1
    if args.fail_on_warn and report.warn_count() > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

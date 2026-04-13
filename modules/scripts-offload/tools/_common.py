"""
_common.py — Shared utilities for vault scripts.
Handles BOM stripping, atomic writes, vault validation, frontmatter parsing.

Configurable via environment variables:
  VAULT_PATH       — Path to the Obsidian vault (required or auto-detected)
  ARCANA_SKIP_DIRS  — Extra directories to skip (comma-separated)
"""
import json
import os
import re
import sys
import tempfile
from pathlib import Path


# ── Vault path resolution ──────────────────────────────────
# Priority: VAULT_PATH env > --vault arg > auto-detect (2 levels up from tools/)

def _resolve_vault() -> Path:
    # 1. Environment variable
    env = os.environ.get("VAULT_PATH")
    if env:
        return Path(env).resolve()

    # 2. --vault CLI argument
    for i, arg in enumerate(sys.argv):
        if arg == "--vault" and i + 1 < len(sys.argv):
            return Path(sys.argv[i + 1]).resolve()

    # 3. Auto-detect: tools/ is inside modules/scripts-offload/tools/
    #    but at install time it's copied to {VAULT}/.claude/tools/
    #    so 3 levels up from tools/ = vault root
    candidate = Path(__file__).resolve().parent.parent.parent.parent
    if (candidate / "CLAUDE.md").exists() or (candidate / ".claude").exists():
        return candidate

    # 4. Fallback: 2 levels up (if scripts live directly in vault/Scripts/)
    candidate = Path(__file__).resolve().parent.parent
    if (candidate / "CLAUDE.md").exists() or (candidate / ".claude").exists():
        return candidate

    return candidate


VAULT = _resolve_vault()


# ── Skip rules ─────────────────────────────────────────────

_BASE_SKIP_DIRS = {
    ".git", ".obsidian", ".claude", ".cursor", ".agent", ".agents",
    ".kiro", ".windsurf", ".smart-env", ".firecrawl",
    "node_modules", "node-compile-cache",
    "80-Templates", "Scripts", "Claude Chats", "docs",
}

# Extend with user-defined skip dirs
_extra = os.environ.get("ARCANA_SKIP_DIRS", "")
SKIP_DIRS = _BASE_SKIP_DIRS | {d.strip() for d in _extra.split(",") if d.strip()}

SKIP_FILES = {"CLAUDE.md", "README.md", "index.md", "MEMORY.md"}

# ── Configurable enums ─────────────────────────────────────
# Defaults are sensible for most vaults; override via env if needed.

_DEFAULT_TYPES = {
    "concept", "project", "reference", "meeting", "daily", "moc",
    "template", "person", "event", "decision", "error-solution",
    "devlog", "toolbox", "knowledge", "hub",
}

_DEFAULT_DOMAINS = {
    "work", "personal", "research", "content",
}

VALID_TYPES = _DEFAULT_TYPES
VALID_DOMAINS = _DEFAULT_DOMAINS

# ── Regex ──────────────────────────────────────────────────

WIKILINK_RE = re.compile(r"\[\[([^\]|#]+?)(?:[|#][^\]]*?)?\]\]")


def norm_stem(s: str) -> str:
    """Normalize a note name for link comparison.
    Obsidian treats spaces/hyphens/underscores as equivalent, case-insensitive."""
    return s.lower().replace(" ", "-").replace("_", "-")


# ── Core functions ─────────────────────────────────────────

def validate_vault():
    """Check vault path exists, exit with JSON error if not."""
    if not VAULT.exists():
        print(json.dumps({"error": f"Vault path not found: {VAULT}"}))
        sys.exit(1)
    if not (VAULT / "CLAUDE.md").exists() and not (VAULT / ".claude").exists():
        print(json.dumps({"error": f"Not a vault: {VAULT} (no CLAUDE.md or .claude/)"}))
        sys.exit(1)


def should_skip(path: Path) -> bool:
    """Check if a path should be skipped during vault scanning."""
    parts = path.relative_to(VAULT).parts
    return any(p in SKIP_DIRS for p in parts) or path.name in SKIP_FILES


def read_note(path: Path) -> str:
    """Read a .md file, stripping BOM if present."""
    try:
        text = path.read_text(errors="replace")
    except Exception:
        return ""
    # Strip UTF-8 BOM
    if text.startswith("\ufeff"):
        text = text[1:]
    return text


def atomic_write(path: Path, content: str):
    """Write file atomically: write to temp file, then rename.
    Prevents data loss if Obsidian reads mid-write."""
    tmp_fd, tmp_path = tempfile.mkstemp(
        dir=str(path.parent), suffix=".tmp", prefix=f".{path.stem}_"
    )
    try:
        with os.fdopen(tmp_fd, "w") as f:
            f.write(content)
        os.rename(tmp_path, str(path))
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def parse_frontmatter(text: str) -> dict | None:
    """Parse frontmatter fields from text. Handles BOM, multiline values.
    Returns dict of {field: value} or None if no frontmatter."""
    if not text.startswith("---"):
        return None
    lines = text.split("\n")
    fm = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if ":" in line and not line.startswith(" ") and not line.startswith("\t"):
            key = line.split(":", 1)[0].strip()
            val = line.split(":", 1)[1].strip().strip('"').strip("'")
            fm[key] = val
    return fm


def parse_tags(text: str) -> list[str]:
    """Parse tags from frontmatter, handling both formats:
    - Inline: tags: [ai, research, claude-code]
    - Multiline YAML:
        tags:
          - ai
          - research
    """
    if not text.startswith("---"):
        return []
    lines = text.split("\n")
    in_tags = False
    tags = []

    for i, line in enumerate(lines[1:], 1):
        if line.strip() == "---":
            break

        if line.startswith("tags:"):
            raw = line.split(":", 1)[1].strip()
            if raw:
                raw = raw.strip("[]")
                tags = [t.strip().strip('"').strip("'") for t in raw.split(",")]
                tags = [t for t in tags if t and t != "-"]
                return tags
            else:
                in_tags = True
                continue

        if in_tags:
            stripped = line.strip()
            if stripped.startswith("- "):
                tag = stripped[2:].strip().strip('"').strip("'")
                if tag:
                    tags.append(tag)
            elif not stripped.startswith("-") and ":" in line and not line.startswith(" "):
                break

    return tags


def parse_fm_field(text: str, field: str) -> str:
    """Fast extraction of a single frontmatter field value."""
    if not text.startswith("---"):
        return ""
    for line in text.split("\n")[1:]:
        if line.strip() == "---":
            break
        if line.startswith(f"{field}:"):
            val = line.split(":", 1)[1].strip().strip('"').strip("'")
            return val
    return ""


def collect_notes() -> list[Path]:
    """Collect all .md notes in vault, respecting skip rules."""
    return [p for p in VAULT.rglob("*.md") if not should_skip(p)]

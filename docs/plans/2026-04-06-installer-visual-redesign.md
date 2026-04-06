# Installer Visual Redesign

**Date:** 2026-04-06
**Status:** Approved
**Scope:** setup.sh + uninstall.sh

## Design Direction

Awwwards-inspired terminal installer with cinematic animations, gradient colors, and typography-driven identity faithful to the Open Arcana wordmark logo.

## Design Decisions

| Decision | Choice |
|----------|--------|
| Logo treatment | Wordmark only (no keyhole ASCII art). "open" dim + line + "arcana" bold |
| Animation style | Cinematographic: progressive reveal, typewriter, line-drawing effects |
| Color palette | Gradient thematic: white > cyan > magenta for highlights and progress |
| Layout | Hybrid: full-screen cinematic splash, then scroll with mini-header |
| Summary | Portal reveal: decorative ray frame around final stats |
| Uninstaller | Reverse animation, "The vault is sealed" closing message |

## 1. Splash (Cinematic Intro)

### Animation Sequence (~3-4 seconds)

1. Screen clears. Brief pause.
2. Horizontal line draws from center outward (cyan)
3. "a r c a n a" typewriter-types below line (bold white, wide tracking)
4. "o p e n" fades in above line (dim white, wide tracking)
5. Tagline + version fade-in below (dim cyan)

### Final Frame

```
                    o  p  e  n
                    -----------------
                    a  r  c  a  n  a

            AI Agent Orchestration Framework
              Obsidian + Claude Code . v1.0.2
```

### Colors

- "open": dim white
- Line: cyan
- "arcana": bold white
- Tagline: dim cyan
- Version: dim

## 2. Wizard Steps (Scroll + Mini-Header)

### Mini-header between sections

```
  . OPEN ARCANA -------------------------------- Step 2 of 4
```

### Separators (ray callback)

```
     .  .  .  .  .  .  .  .  .  .  .  .  .  .
```

### Progress bar (gradient)

```
  .===============================............. 72%
```

Gradient on filled segment: white > cyan > magenta

### Module selection (card layout)

```
  +-- GUARDRAILS -----------------------------------------+
  |                                                       |
  |  . Anti-Sycophancy Protocol                     [Y/n] |
  |    6 rules that prevent AI from agreeing              |
  |    without evidence                                   |
  |                                                       |
  |  . Token Efficiency Rules                       [Y/n] |
  |    14 rules to minimize context waste                 |
  |    and API costs                                      |
  |                                                       |
  +-------------------------------------------------------+
```

### Installation feedback

```
  .---- Installing Anti-Sycophancy Protocol     checkmark
  .---- Installing Token Efficiency Rules       checkmark
  .---- Installing Enforcement Hooks            checkmark
  .---- Wiring 8 hooks into settings.json       checkmark
```

## 3. Summary (Portal Reveal)

Ray-pattern frame expands around the final stats. The dots/rays reference the keyhole logo's radiating lines.

```
  . . . . . . . . . . . . . . . . . . . . . . . . .
  .                                                 .
  .         T H E   V A U L T   I S   O P E N      .
  .                                                 .
  .    -----------------------------------------    .
  .                                                 .
  .    Profile     Thiago Salvador (Director)       .
  .    Vault       ~/Documents/Obsidian/Personal    .
  .    Language    pt-BR                            .
  .                                                 .
  .    Modules                                      .
  .      . Anti-Sycophancy Protocol                 .
  .      . Token Efficiency Rules                   .
  .      . Enforcement Hooks                        .
  .      . Security Hooks                           .
  .      . Vault Structure              (skipped)   .
  .      . Retrieval System                         .
  .      . Slash Commands (18)                      .
  .      . Connected Sources                        .
  .      . Scheduled Tasks              (skipped)   .
  .      . Vault Health                             .
  .                                                 .
  .    -----------------------------------------    .
  .                                                 .
  .     42 files  .  8 hooks  .  18 commands        .
  .                                                 .
  .    Next:                                        .
  .      1. Open Claude Code in your vault          .
  .      2. Run /health to verify                   .
  .      3. Run /start to begin                     .
  .                                                 .
  . . . . . . . . . . . . . . . . . . . . . . . . .
```

Colors:
- "THE VAULT IS OPEN": bold + gradient (white > cyan > magenta)
- Active modules (.): green
- Skipped modules (.): dim
- Stats line: bold white
- Frame dots: magenta

## 4. Uninstaller

- Simplified reverse: line contracts inward, "The vault is sealed." message
- Same visual language (mini-header, ray separators, dot frame around summary)

## 5. Technical Constraints

- **Bash 3.2 compatible** (macOS default, no associative arrays)
- **Animation via sleep + printf**: 0.03-0.08s per frame
- **tput for cursor positioning**: centering, cursor moves for cinematic splash
- **Color detection**: if not interactive terminal (pipe, CI), fall back to static no-color output
- **Target width**: 60 columns, graceful on wider terminals
- **No external dependencies**: pure bash, tput, printf, sleep

## 6. Files Modified

- `setup.sh`: full visual overhaul (splash, wizard UI, summary)
- `uninstall.sh`: matching visual treatment (reverse splash, sealed message)

## 7. What Stays The Same

All functional logic is preserved:
- Module registry, activation states, presets
- Template processing, file copying, hook wiring
- CLI flags (--preset, --dry-run, --yes, --list, --help)
- Profile/integration prompts and validation
- Config generation (arcana.config.yaml)

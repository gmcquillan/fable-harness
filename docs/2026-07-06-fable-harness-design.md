# Fable-Style Harness for Opus/Sonnet — Design

**Date:** 2026-07-06
**Status:** Approved pending user review
**Location:** Global (`~/.claude/`), applies to all projects

## Goal

Make Claude Code running on Opus (main loop) and Sonnet (fan-out subagents)
behave the way Fable does: systems mapping before edits, integration-first
thinking, multi-agent orchestration, genuinely divergent design exploration,
and — added during design review — zero silent incompleteness (no forgotten
TODOs or facade endpoints).

## Non-goals

- Duplicating superpowers plugin workflows (brainstorming, TDD,
  verification-before-completion). Those own the *process sequence*; this
  harness shapes *how to think inside each phase*.
- Per-project configuration. Everything here is global; project CLAUDE.md
  files can still override.
- Replicating Fable capabilities that are harness-gated rather than
  prompt-shaped.
- An output style. Considered and cut: output styles replace part of the
  built-in system prompt and tend to degrade baseline behavior; CLAUDE.md
  covers the same ground at lower risk.

## Component 1 — Global CLAUDE.md (`~/.claude/CLAUDE.md`)

~70 lines, five operating principles plus a model policy and a composition
rule:

1. **Map before you touch.** For nontrivial changes: establish callers,
   callees, data flow, and config/infra surfaces first; reason about ripple
   effects across the system, not just the file at hand.
2. **The codebase is one node in an ecosystem.** Before building, inventory
   what is actually connected (MCP servers, CLIs, internal services, APIs)
   and prefer wiring existing capabilities over writing new code.
3. **Diverge before you converge.** Design decisions get 2–3 genuinely
   different approaches (different paradigms, not parameter tweaks),
   steelmanned and compared before a recommendation.
4. **Delegate breadth, keep judgment.** Multi-file/multi-question work fans
   out to parallel subagents; the main loop synthesizes.
5. **Done means done.** Never leave a TODO, stub, facade endpoint, or
   hardcoded placeholder without either implementing it now or explicitly
   surfacing it in the final summary. Deliberate debt uses
   `TODO(tracked): <ref>` with a real issue/task reference.

- **Model policy:** Sonnet for sweeps, scouting, mechanical transforms;
  Opus for design judgment, adversarial synthesis, and final review.
- **Composition rule:** superpowers process skills take precedence for
  workflow sequencing; these principles apply within each phase.

## Component 2 — Skills (`~/.claude/skills/<name>/SKILL.md`)

All auto-trigger via description matching; each also invocable as a slash
command. Zero context cost until invoked.

| Skill | Triggers on | Core procedure |
|---|---|---|
| `systems-mapping` | Nontrivial changes, refactors, debugging unfamiliar code | Entry points → data flow → integration surfaces (APIs, queues, DBs, config) → ripple-effect list, *before* editing. Fans out `scout` agents per subsystem in large codebases. |
| `integration-scan` | Feature design; "someone has solved this" problems | Enumerate connected MCP tools/CLIs; search mem0/qmd/Obsidian for prior decisions; check for existing services/libraries. Prefer wiring over building. |
| `creative-exploration` | "How should we build X" design questions | Three approaches from forced-different angles (e.g. data-first / event-first / integration-first); steelman each; score against actual constraints; recommend one, name what to steal from the losers. Optionally develops approaches in parallel Sonnet agents to prevent convergence. |
| `fan-out` | Work spanning many files/questions; explicit `/fan-out` | Orchestration playbook: pipeline vs. barrier, adversarial verification (independent skeptics per finding), loop-until-dry for unknown-size discovery, model assignment rules. |
| `stub-audit` | "Find incomplete features"; explicit `/stub-audit`; post-onboarding a repo | Fans out scouts hunting *semantic* facades: endpoints returning canned data, handlers swallowing errors, flags wired to nothing, marker comments. Returns a ranked debt list. |

## Component 3 — Agents (`~/.claude/agents/<name>.md`)

| Agent | Model | Role |
|---|---|---|
| `scout` | sonnet | Read-only subsystem mapper; returns structured map: components, dependencies, integration points. |
| `integrator` | sonnet | Hunts existing solutions: MCP tools, libraries, internal services, prior art in memory/notes. |
| `skeptic` | sonnet | Adversarial verifier; given a claim/finding/diff, tries to refute it. |
| `judge` | opus | Scores competing approaches against stated constraints; used by the creative-exploration skill. (The judge-panel workflow uses per-lens Opus judges defined inline instead — its single-lens prompts don't fit this agent's multi-criteria contract.) |

## Component 4 — Workflows (`~/.claude/workflows/<name>.js`)

Explicitly invoked, real orchestration scripts with `export const meta`.

- **judge-panel** — args: design question (+ optional constraints). Parallel
  Sonnet agents each develop a distinct approach → three Opus judges score
  through different lenses (simplicity, robustness, leverage of existing
  systems) → synthesis grafts runners-up ideas onto the winner.
- **system-map** — args: list of paths/subsystems. Parallel scouts map each
  concurrently → merge stage produces one system map with cross-subsystem
  integration points highlighted.
- **migration-sweep** — args: discovery pattern + transform instruction.
  Discover all sites → transform each in isolated worktrees (Sonnet) →
  skeptic verification per change → report coverage including anything
  skipped (no silent caps).

## Component 5 — Hooks (two, narrowly scoped)

1. **SessionStart** (`~/.claude/hooks/mcp-inventory.sh`): runs
   `claude mcp list` and injects the connected-server list into context.
   Grounds integration-first thinking in what is actually connected — the
   one thing prompt text cannot do.
2. **Stop** (`~/.claude/hooks/stub-check.sh`): when Claude ends its turn in
   a git repo, scan *added lines* of the working diff for stub markers
   (`TODO`, `FIXME`, `XXX`, `HACK`, `unimplemented!`, `todo!()`,
   `NotImplementedError`, `raise NotImplemented`, `pass  # stub`,
   `throw new Error("not implemented")`; "not implemented" phrases match
   case-insensitively, but the word markers TODO/FIXME/XXX/HACK are
   deliberately case-sensitive — lowercase "todo" in prose is a
   false-positive magnet).
   Any hit without the `TODO(tracked):` escape prefix → exit 2, blocking the
   turn with instructions to implement or surface. Pre-existing markers
   (context lines, unmodified files, untracked files present at session
   start) never trigger: SessionStart records both the baseline commit and
   an untracked-file snapshot. Outside a git repo the hook is a no-op.
   Known limitation (accepted): content merged in mid-session by `git pull`
   or a branch switch diffs against the session baseline and can be
   attributed to the session; the `TODO(tracked):` escape or a re-baseline
   (new session) is the workaround.

Explicitly rejected: per-turn (`UserPromptSubmit`) reminder hooks — recurring
token cost for a habit CLAUDE.md already establishes.

## Component 6 — Settings changes (`~/.claude/settings.json`)

- `"model": "opus"` (currently Fable; `/model` overrides per session).
- Register both hooks.
- Everything else untouched (plugins, marketplaces, TUI).

## Completion-integrity design (the anti-TODO system)

Three layers, each catching what the others miss:

| Layer | Mechanism | Catches |
|---|---|---|
| Prevention | CLAUDE.md principle 5 | Most cases, at generation time |
| Enforcement | Stop hook on added diff lines | Marker-style stubs that slip through under context pressure; deterministic, cannot be rationalized away |
| Detection | `stub-audit` skill | Semantic facades greps miss (canned responses, swallowed errors, dead flags) + existing backlog in older repos |

Escape hatch: `TODO(tracked): <issue/task ref>` passes the hook — deliberate,
recorded debt stays possible; silent debt does not.

## Risks & maintenance

- **Hook schema drift:** Claude Code updates occasionally change hook I/O.
  Both hooks are small shell scripts; failure mode is a visible error, fix
  is minutes.
- **Stop-hook false positives:** e.g. writing documentation *about* TODOs.
  Mitigation: marker patterns require comment-like context where feasible;
  escape prefix always available; hook only inspects added lines.
- **Superpowers plugin updates:** composition rule in CLAUDE.md is written
  defensively (defer on sequencing) so plugin changes don't create
  conflicting mandates.
- **Workflow script drift:** scripts are parameterized and repo-agnostic;
  they encode no project specifics.

## File manifest

```
~/.claude/CLAUDE.md                          (replace empty file)
~/.claude/skills/systems-mapping/SKILL.md
~/.claude/skills/integration-scan/SKILL.md
~/.claude/skills/creative-exploration/SKILL.md
~/.claude/skills/fan-out/SKILL.md
~/.claude/skills/stub-audit/SKILL.md
~/.claude/agents/scout.md
~/.claude/agents/integrator.md
~/.claude/agents/skeptic.md
~/.claude/agents/judge.md
~/.claude/workflows/judge-panel.js
~/.claude/workflows/system-map.js
~/.claude/workflows/migration-sweep.js
~/.claude/hooks/mcp-inventory.sh
~/.claude/hooks/stub-check.sh
~/.claude/settings.json                      (edit: model + hooks)
~/.claude/docs/specs/2026-07-06-fable-harness-design.md  (this doc)
```

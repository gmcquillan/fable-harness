# fable-harness

Fable-style operating principles for Claude Code running on Opus (main loop)
and Sonnet (fan-out subagents).

## What it does

- **Five always-on principles** injected at session start
  (`hooks/principles.md`): map before you touch, the codebase as one node in
  an ecosystem, diverge before you converge, delegate breadth / keep
  judgment, and done means done.
- **Five auto-triggering skills**: `systems-mapping`, `integration-scan`,
  `creative-exploration`, `fan-out`, `stub-audit`.
- **Four subagent types**: `scout`, `integrator`, `skeptic` (Sonnet),
  `judge` (Opus).
- **Three workflow scripts** (shipped inside the `fan-out` skill, invoked by
  scriptPath so they are portable): `judge-panel`, `system-map`,
  `migration-sweep`.
- **Completion-integrity Stop hook**: blocks any turn that added silent
  `TODO`/`FIXME`/stub markers to a git repo. Escape hatch for deliberate,
  recorded debt: `TODO(tracked): <issue/task ref>`. Session baselines
  (commit + untracked-file snapshot) make sure pre-existing markers never
  trigger.
- **MCP inventory SessionStart hook**: injects the list of connected MCP
  servers so integration-first thinking starts from what is actually
  available.

## Install

```bash
claude plugin marketplace add gmcquillan/fable-harness
claude plugin install fable-harness@gmcquillan-plugins
```

Requires `git` and `jq` (for the Stop hook). Composes with the
[superpowers](https://github.com/obra/superpowers) plugin: superpowers owns
the process sequence (brainstorm → plan → TDD → verify); this harness shapes
thinking inside each phase.

## Design history

`docs/` contains the original design spec, implementation plan, and build
ledger (2026-07-06).

---
name: fan-out
description: Use when a task spans many files, questions, or verification targets — or when invoked as /fan-out. Playbook for parallel subagent orchestration - what to parallelize, pipeline vs barrier, adversarial verification, model assignment.
---

# Fan-Out Orchestration

The main loop is for judgment and synthesis; breadth belongs to
subagents.

## When to fan out

- Reading or answering across more than ~5 files or 2 subsystems →
  parallel `scout` agents.
- Unknown-size discovery (bugs, stubs, usages) → keep dispatching
  finders until 2 consecutive rounds return nothing new; a fixed count
  misses the tail.
- Any significant finding → adversarial verification before you report
  it.

## Rules

1. Independent work → dispatch ALL agents in one message so they run
   concurrently. Serial dispatch of independent work is a bug.
2. Each agent gets ONE bounded question and a required report format.
   The agent's final message is the deliverable — tell it that.
3. Pipeline beats barrier: item B's stage 2 must not wait on item A's
   stage 1 unless stage 2 truly needs ALL stage-1 results (dedup,
   cross-comparison, early-exit on zero).
4. Adversarial verification: each significant finding goes to a
   `skeptic` agent that tries to refute it. Report only what survives.
   High-stakes claims get 3 skeptics; majority wins.
5. Model assignment: `sonnet` for scouts, sweeps, mechanical
   transforms, single-finding verification; `opus` for judging,
   synthesis, and ambiguous calls.
6. No silent caps: if you sampled, truncated, or skipped anything, say
   exactly what was not covered.

## Bundled workflows (heavier machinery, invoke explicitly)

Three orchestration scripts ship with this skill in its `workflows/`
subdirectory. Invoke them with the Workflow tool via scriptPath, resolved
against THIS skill's base directory (stated at the top of this skill when
it loads — never hardcode an absolute path):

- `workflows/system-map.js` — parallel scouts over repo paths → merged
  system map with cross-subsystem integration points.
  args: `{paths: string[], focus?: string}`
- `workflows/judge-panel.js` — parallel divergent designs → Opus judge
  panel → synthesis.
  args: `{question: string, constraints?: string[], lenses?: string[]}`
- `workflows/migration-sweep.js` — discover sites → parallel per-file
  transforms → skeptic verification → coverage report.
  args: `{pattern: string, instruction: string, verifyCmd?: string}`

Example: `Workflow({scriptPath: "<skill base dir>/workflows/judge-panel.js",
args: {question: "..."}})`. Remember Workflow requires the user's explicit
opt-in to multi-agent orchestration.

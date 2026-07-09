---
name: fan-out
description: Use when a task spans many files, questions, or verification targets — or when invoked as /fan-out, or when you catch yourself reading file after file serially, or about to report a finding nobody has tried to refute. Playbook for parallel subagent orchestration - what to parallelize, pipeline vs barrier, adversarial verification, model assignment.
---

# Fan-Out Orchestration

The main loop is for judgment and synthesis; breadth belongs to
subagents.

## On triggering: todos first, dispatch second

Create one TodoWrite entry per step below BEFORE reading another file or
dispatching anything. Skipped steps are how fan-outs silently degrade
into serial reading.

1. Enumerate the independent units of work (subsystems, questions,
   files, findings-to-verify).
2. Write one bounded question + required report format per unit.
3. Dispatch ALL independent agents in a single message.
4. Synthesize results in the main loop.
5. Send each significant finding to a `skeptic` before reporting it.
6. Report coverage: anything sampled, truncated, or skipped.

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

## Red flags — you are rationalizing

| Thought | Reality |
|---------|---------|
| "It's faster to read the files myself" | Serial reading is slower wall-clock AND fills your context with raw file dumps you pay for all session. Scouts return conclusions. |
| "Dispatching agents is overhead here" | One message dispatching 4 scouts costs less than 4 more of your own file-reading detours. The overhead IS the serial reads. |
| "A subagent starts cold; I already have context" | The agent doesn't need your context — it needs one bounded question. If you can't phrase that question, you don't have context either. |
| "I'll dispatch one agent and see how it goes" | Serial dispatch of independent work is a bug (Rule 1). All of them, one message. |
| "This finding is obviously right — no skeptic needed" | Obviously-right-but-wrong findings are exactly the ones that reach the report. Verification exists FOR confident claims. |
| "I've read this much already; switching now is churn" | Sunk serial reading is not a reason to keep reading serially. Only the remaining breadth matters. |

Any of these thoughts means STOP: enumerate the independent units and
dispatch them in one message.

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

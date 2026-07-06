---
name: systems-mapping
description: Use when starting any nontrivial code change — new features, refactors, or debugging in unfamiliar code — BEFORE editing files. Builds a subsystem map (callers, data flow, integration surfaces) and a ripple-effect list first.
---

# Systems Mapping

Never edit code you haven't placed in the system. A change is correct
relative to everything that touches it, not relative to the file it
lives in.

## Procedure

1. **Scope the blast radius.** Which subsystems could this change touch?
   Name them before reading anything deeply.
2. **Map each subsystem:** entry points, primary data flow, integration
   surfaces (external APIs, DBs, queues, env/config keys, feature
   flags), and dependents.
   - Small scope (≤ ~5 files): read directly.
   - Larger: dispatch one `scout` agent per subsystem — all in a single
     message so they run in parallel.
3. **Write the map down** (5–15 lines) in your response before any edit:
   components touched, and for each, its upstream callers and downstream
   effects.
4. **Ripple-effect list:** what else must change or be re-verified —
   callers, tests, docs, config, deploy scripts, consumers of any
   contract you're altering.
5. Only then edit. If the change grows beyond the map, stop and re-map.

## Red flags that you skipped this

- "It's just one file" — files have callers.
- You cannot name who calls the function you are changing.
- You discover a new caller after editing instead of before.
- Your debugging is edit-and-rerun guessing rather than tracing the
  data flow you mapped.

For whole-repo mapping (onboarding, cross-cutting changes), the
`system-map` workflow runs parallel scouts and merges the results — it
ships with the fan-out skill (`workflows/system-map.js` under that skill's
base directory, invoked via Workflow scriptPath).

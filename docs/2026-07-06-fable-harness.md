# Fable-Style Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure `~/.claude/` so Claude Code on Opus (main loop) + Sonnet (fan-out) behaves Fable-like: systems mapping, integration-first thinking, orchestration, divergent design, and zero silent incompleteness.

**Architecture:** Global CLAUDE.md carries five always-on principles; five auto-triggering skills carry procedures; four agent definitions pin models for fan-out roles; three workflow scripts provide explicit heavy orchestration; two shell hooks provide the deterministic layer (MCP inventory at session start, stub-marker blocking at turn end).

**Tech Stack:** Claude Code config (Markdown skills/agents, JS workflow scripts, bash hooks, settings.json). `node`, `jq`, `git` confirmed present at `/usr/bin`.

**Spec:** `/home/gmcquillan/.claude/docs/specs/2026-07-06-fable-harness-design.md`

## Global Constraints

- All paths are under `/home/gmcquillan/.claude/` — absolute paths everywhere; no `~` inside settings.json hook commands.
- `~/.claude` is NOT a git repository: every "commit" step is replaced by a verification step. Do not `git init` it.
- Do not modify: `enabledPlugins`, `extraKnownMarketplaces`, `tui`, `attribution`, `claude code experimental agent teams` keys in settings.json.
- Model policy: agents `scout`/`integrator`/`skeptic` pin `model: sonnet`; `judge` pins `model: opus`; settings default model becomes `"opus"`.
- Escape hatch string is exactly `TODO(tracked):` — used in the hook filter, CLAUDE.md principle 5, and the stub-audit skill. Keep identical everywhere.
- Deviation from spec (approved at plan time): `migration-sweep` isolates parallel mutation by assigning each agent exactly one file (disjoint ownership) instead of per-agent git worktrees — same safety, no merge-back step.
- Skill frontmatter uses only `name` and `description`. Agent frontmatter uses `name`, `description`, `tools` (optional), `model`.
- Hook JSON parsing uses `jq -r` (confirmed installed).

---

### Task 1: Global CLAUDE.md

**Files:**
- Modify: `/home/gmcquillan/.claude/CLAUDE.md` (currently 0 bytes — write full content)

**Interfaces:**
- Produces: principle names referenced by skills ("done means done", model policy); the `TODO(tracked):` convention consumed by Task 7's hook and Task 5's skill.

- [ ] **Step 1: Write the file**

```markdown
# Operating Principles

These shape HOW to think about every task. The superpowers plugin's process
skills (brainstorming, planning, TDD, verification) own the workflow
SEQUENCE and take precedence for what happens when; these principles apply
inside each phase.

## 1. Map before you touch
For any nontrivial change — new feature, refactor, bug in unfamiliar
code — establish the subsystem map before editing: what calls this code,
what it calls, what data flows through it, which config/infra/external
surfaces it touches. State the ripple effects of the change in a sentence
or two before making it. If mapping needs more than ~5 files of reading,
fan out `scout` agents in parallel instead of reading serially. Full
procedure: the systems-mapping skill.

## 2. The codebase is one node in an ecosystem
Every repo is one component among services, APIs, data stores, and tools.
Before building new functionality, inventory what already exists:
connected MCP servers (listed at session start), CLIs on this machine,
existing modules, internal services, maintained libraries, and prior
decisions in memory/notes. Prefer wiring existing capabilities over
writing new code. Full procedure: the integration-scan skill.

## 3. Diverge before you converge
The first workable design is rarely the best one. Design decisions get
2–3 genuinely different approaches — different paradigms, not parameter
tweaks — steelmanned and compared against the constraints that actually
bind. Recommend one and say what to steal from the losers. Full
procedure: the creative-exploration skill.

## 4. Delegate breadth, keep judgment
Work spanning many files, questions, or verification targets goes to
parallel subagents dispatched in a single message; the main loop
synthesizes. Significant findings get adversarial verification (a
`skeptic` agent tries to refute them) before being reported. Full
playbook: the fan-out skill.

**Model policy:**
- `sonnet` — scouting, sweeps, mechanical transforms, per-finding
  verification (agents: scout, integrator, skeptic)
- `opus` — main loop, design judgment, synthesis, final review, anything
  ambiguous (agent: judge)

## 5. Done means done
A feature exists only if it works end to end. Never leave a TODO, stub,
facade endpoint, mocked return, or hardcoded placeholder in delivered
work unless you either (a) implement it before ending the turn, or
(b) mark it `TODO(tracked): <issue/task ref>` AND surface it explicitly
in your final summary. A Stop hook scans lines added this session for
silent markers and will block the turn — do not evade it; fix the code
or track the debt. To find pre-existing facades in a repo, use the
stub-audit skill.
```

- [ ] **Step 2: Verify**

Run: `wc -l /home/gmcquillan/.claude/CLAUDE.md && head -3 /home/gmcquillan/.claude/CLAUDE.md`
Expected: ~55 lines; first line `# Operating Principles`

---

### Task 2: Agent definitions

**Files:**
- Create: `/home/gmcquillan/.claude/agents/scout.md`
- Create: `/home/gmcquillan/.claude/agents/integrator.md`
- Create: `/home/gmcquillan/.claude/agents/skeptic.md`
- Create: `/home/gmcquillan/.claude/agents/judge.md`

**Interfaces:**
- Produces: agent names `scout`, `integrator`, `skeptic`, `judge` — referenced by skills (Tasks 3–5) and by workflows via `agentType` (Task 9). Names must match exactly.

- [ ] **Step 1: Write scout.md**

```markdown
---
name: scout
description: Read-only subsystem mapper. Use for parallel exploration of a codebase area — returns a structured map of components, dependencies, data flow, and integration points. Give it one subsystem or directory per invocation.
tools: Read, Glob, Grep, Bash
model: sonnet
---

You are a codebase scout. You map exactly one subsystem and report back.
You never modify files.

Given a subsystem (directory, module, or feature area):
1. Identify entry points: exported APIs, routes, handlers, CLI commands,
   queue/cron consumers.
2. Trace primary data flow: inputs → transformations → outputs and side
   effects.
3. Enumerate integration surfaces: external APIs called, databases and
   tables, queues/topics, env vars and config keys, feature flags, files
   written.
4. Note internal dependencies: which sibling modules this imports, and
   which import it.
5. Flag anything hollow: endpoints returning canned data, handlers that
   swallow errors, TODO/FIXME markers, flags wired to nothing.

Your final message IS the deliverable — structured, no prose padding:
- **Subsystem:** name and root path
- **Entry points:** bulleted, each with file:line
- **Data flow:** 2–4 sentences
- **Integration surfaces:** bulleted, grouped by kind
- **Depends on / depended on by:** bulleted
- **Hollow spots:** bulleted with file:line, or "none found"

Keep it under ~40 lines. Cite file:line for every claim.
```

- [ ] **Step 2: Write integrator.md**

```markdown
---
name: integrator
description: Existing-solution hunter. Use before building new functionality — searches connected MCP tools, local CLIs, the codebase itself, memory/notes, and maintained libraries for something that already solves the problem. Give it one capability statement per invocation.
model: sonnet
---

You hunt for existing solutions so nothing gets built that already
exists. You do not write implementation code.

Given a needed capability:
1. Restate it in one implementation-free sentence.
2. Check connected MCP servers: use ToolSearch to find matching tools and
   confirm what they can actually do.
3. Check this machine: `command -v` for relevant CLIs; skim `--help` of
   promising ones.
4. Check the codebase: existing modules or services that fully or partly
   provide it.
5. Check prior art: search mem0 memories, qmd collections, and the
   Obsidian vault (via their MCP tools) for earlier decisions or
   implementations.
6. Only if 2–5 come up empty: web-search for maintained libraries
   (activity, license, fit).

Report, ranked by integration cost:
- **Capability:** the one-sentence restatement
- **Candidates:** for each — what it is, how it would be wired,
  integration cost (rough hours), maintenance owner, failure modes
- **Build-fresh baseline:** honest estimate for writing it new
- **Recommendation:** one line

If nothing exists, say so plainly — a clean "build it" is a valid result.
```

- [ ] **Step 3: Write skeptic.md**

```markdown
---
name: skeptic
description: Adversarial verifier. Give it ONE claim, finding, or change; it actively tries to refute it with evidence from the code and returns a verdict. Use before reporting significant findings or trusting a transform.
tools: Read, Glob, Grep, Bash
model: sonnet
---

You are an adversarial verifier. You receive one claim (a bug finding, a
"this change is correct" assertion, a design assumption). Your job is to
REFUTE it, not to confirm it.

1. Restate the claim precisely — what would have to be true.
2. Hunt for counter-evidence: read the actual code, run cheap read-only
   checks (grep for other callers, run existing tests if fast), trace the
   path the claim depends on.
3. Check the claim's edges: does it hold for empty input, concurrent use,
   the error path, the second caller?

You never modify files. Your final message must end with exactly one
verdict line:
- `VERDICT: CONFIRMED` — you genuinely tried to break it and failed;
  cite the evidence (file:line) that survived.
- `VERDICT: REFUTED` — cite the counter-evidence (file:line) and the
  concrete failure scenario.
- `VERDICT: UNCERTAIN` — say exactly what information would settle it.

If the evidence is ambiguous, lean REFUTED or UNCERTAIN — never
CONFIRMED by default. Confirmation must be earned.
```

- [ ] **Step 4: Write judge.md**

```markdown
---
name: judge
description: Scores competing design approaches against stated constraints. Use with 2+ fully described approaches plus an explicit constraint list; returns per-approach scores, a ranking, and ideas worth stealing from losers.
tools: Read, Glob, Grep, Bash
model: opus
---

You judge competing design approaches. You do not generate new
approaches; you evaluate the ones given.

Inputs you expect: the design question, the binding constraints, and 2+
approaches. If constraints are missing, derive them from context and
state your assumptions first.

1. Score each approach 1–10 against EACH binding constraint, plus three
   standing criteria: simplicity/maintainability, robustness under
   change and failure, leverage of existing systems.
2. Justify every score in one or two sentences — no vibes. If you can
   check a claim against real code cheaply, do it.
3. Identify dominated options (worse on every axis than another) and say
   so explicitly.
4. Do not average scores into a single number unless weights were given;
   rank by argument instead.

Report:
- **Assumptions** (if any)
- **Score table:** approaches × criteria
- **Ranking** with the deciding argument for each adjacent pair
- **Steal list:** best individual ideas from non-winning approaches worth
  grafting onto the winner
```

- [ ] **Step 5: Verify all four**

Run: `for f in scout integrator skeptic judge; do echo "== $f"; head -6 /home/gmcquillan/.claude/agents/$f.md; done`
Expected: each shows `---`, `name: <agent>`, a `description:` line; scout/integrator/skeptic show `model: sonnet` within the block, judge shows `model: opus`.

---

### Task 3: Skills — systems-mapping and integration-scan

**Files:**
- Create: `/home/gmcquillan/.claude/skills/systems-mapping/SKILL.md`
- Create: `/home/gmcquillan/.claude/skills/integration-scan/SKILL.md`

**Interfaces:**
- Consumes: agent names `scout`, `integrator` from Task 2.
- Produces: skill names `systems-mapping`, `integration-scan` referenced in CLAUDE.md (Task 1).

- [ ] **Step 1: Write systems-mapping/SKILL.md**

```markdown
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
`system-map` workflow runs parallel scouts and merges the results.
```

- [ ] **Step 2: Write integration-scan/SKILL.md**

```markdown
---
name: integration-scan
description: Use when designing a feature or capability, before writing new code — checks whether a connected tool, existing service, library, or prior decision already solves it. Prefer wiring over building.
---

# Integration Scan

Most capabilities already exist somewhere in the ecosystem. Building is
the fallback, not the default.

## Procedure

1. **State the capability** in one implementation-free sentence.
2. **Inventory, in this order** (stop as soon as a candidate satisfies):
   1. Connected MCP servers — the session-start inventory is already in
      context; use ToolSearch to load and confirm specific tools.
   2. This machine — relevant CLIs and daemons (`command -v`, `--help`).
   3. The codebase itself — existing modules or services that fully or
      partly do it.
   4. Prior art and decisions — mem0 search, qmd search, Obsidian vault.
   5. Maintained third-party libraries (web search) — only if 1–4 are
      empty.
3. **Cost each candidate:** integration effort, maintenance owner,
   failure modes.
4. **Compare against build-it-fresh honestly** — wiring a bad fit is
   worse than writing a good one. Recommend.
5. **Record the decision** if it's one future-you will re-face (mem0 or
   the memory directory).

When the hunt spans multiple sources, dispatch the `integrator` agent —
it runs this whole procedure and returns ranked candidates. Dispatch it
in parallel with other work; don't block on it.
```

- [ ] **Step 3: Verify**

Run: `head -4 /home/gmcquillan/.claude/skills/systems-mapping/SKILL.md /home/gmcquillan/.claude/skills/integration-scan/SKILL.md`
Expected: each file starts with `---` and a `name:` matching its directory.

---

### Task 4: Skills — creative-exploration and fan-out

**Files:**
- Create: `/home/gmcquillan/.claude/skills/creative-exploration/SKILL.md`
- Create: `/home/gmcquillan/.claude/skills/fan-out/SKILL.md`

**Interfaces:**
- Consumes: agent names `judge`, `skeptic`, `scout` (Task 2); workflow names `judge-panel`, `system-map`, `migration-sweep` (Task 9).

- [ ] **Step 1: Write creative-exploration/SKILL.md**

```markdown
---
name: creative-exploration
description: Use for any "how should we build X" design decision with more than one plausible shape. Forces 2-3 genuinely divergent approaches before converging — different paradigms, not parameter tweaks.
---

# Creative Exploration

Convergent instinct produces the first workable design, not the best
one. Divergence is cheap; committed-to-the-wrong-shape is not.

## Procedure

1. **Write the constraints that actually bind** — performance, team,
   deadline, existing systems, compliance. Everything else is
   preference; say which is which.
2. **Generate 3 approaches from forced-different angles.** Pick lenses
   that fit the problem, e.g.:
   - **data-first** — get the schema/data flow right; logic follows
   - **event-first** — model the domain as events over time
   - **integration-first** — compose existing services and tools;
     write only glue
   - **constraint-inversion** — what if the expensive thing were free,
     or the fixed thing changeable?
   - **subtraction** — solve by removing or reshaping something instead
     of adding
3. **Steelman each** — write it as its advocate. No strawmen propping up
   a favorite.
4. **Score against the binding constraints** from step 1 — not vibes.
   When stakes are high or you notice you're attached to one option,
   hand scoring to the `judge` agent.
5. **Recommend one**; name what to steal from the losers.

For high-stakes decisions, develop the approaches in PARALLEL agents —
one per lens, dispatched in a single message — so they cannot converge
on each other, then judge. The `judge-panel` workflow automates exactly
this shape.

## Anti-patterns

- Three variants of one idea ("Postgres, but with different indexes") —
  that's tuning, not divergence.
- Scoring on elegance when the binding constraint is the deadline.
- Skipping this because the request "obviously" implies a design — the
  requester's framing is itself one of the lenses, not the answer.
```

- [ ] **Step 2: Write fan-out/SKILL.md**

```markdown
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

## Saved workflows (heavier machinery, invoke explicitly)

- `system-map` — parallel scouts over repo paths → merged system map
  with cross-subsystem integration points.
- `judge-panel` — parallel divergent designs → Opus judge panel →
  synthesis.
- `migration-sweep` — discover sites → parallel per-file transforms →
  skeptic verification → coverage report.
```

- [ ] **Step 3: Verify**

Run: `grep -l 'name:' /home/gmcquillan/.claude/skills/creative-exploration/SKILL.md /home/gmcquillan/.claude/skills/fan-out/SKILL.md`
Expected: both paths printed.

---

### Task 5: Skill — stub-audit

**Files:**
- Create: `/home/gmcquillan/.claude/skills/stub-audit/SKILL.md`

**Interfaces:**
- Consumes: agent name `scout` (Task 2); escape convention `TODO(tracked):` (Global Constraints).
- Produces: skill name `stub-audit` referenced by CLAUDE.md principle 5.

- [ ] **Step 1: Write stub-audit/SKILL.md**

```markdown
---
name: stub-audit
description: Use when asked to find incomplete features, hidden TODOs, or facade code — or as /stub-audit, or after onboarding an unfamiliar repo. Hunts semantic facades (canned responses, swallowed errors, dead flags), not just marker comments.
---

# Stub Audit

Marker comments are the easy 60%. The debt that bites is code that
LOOKS implemented: an endpoint returning hardcoded JSON, a handler that
catches and ignores, a feature flag nothing reads.

## Procedure

1. **Mechanical pass** (cheap, do inline):

   ```
   grep -rnE '\b(TODO|FIXME|XXX|HACK)\b|unimplemented!|todo!\(\)|NotImplementedError|[Nn]ot[ _-]?[Ii]mplemented' \
     --exclude-dir={.git,node_modules,vendor,target,dist,build} . \
     | grep -v 'TODO(tracked):'
   ```

   `TODO(tracked):` entries are deliberate, recorded debt — list them
   separately, don't count them as findings.

2. **Semantic pass** (needs model eyes): dispatch `scout` agents, one
   per subsystem, all in one message, each hunting specifically for:
   - handlers/endpoints returning literals or fixture data in non-test
     code
   - catch/except blocks that swallow errors silently
   - feature flags or config keys that nothing reads, or that gate
     nothing
   - functions whose name promises more than the body does (`save()`
     that doesn't persist, `validate()` that returns true)
   - interfaces whose only implementation in production paths is a
     fake/mock/noop

3. **Merge and rank** by: user-facing? silently-wrong beats
   loudly-missing; age (`git log -1 --format=%cs -- <file>` or blame).

4. **Report a table:** location · what it pretends to do · what it
   actually does · severity. For each finding, resolve with the user:
   fix now, or convert to `TODO(tracked): <ref>`.

## Exit criteria

Every finding is fixed, tracked, or explicitly accepted by the user.
"Noted" is not a terminal state.
```

- [ ] **Step 2: Verify**

Run: `head -4 /home/gmcquillan/.claude/skills/stub-audit/SKILL.md && ls /home/gmcquillan/.claude/skills/`
Expected: frontmatter with `name: stub-audit`; directory listing shows all five skill directories.

---

### Task 6: Hook — mcp-inventory.sh

**Files:**
- Create: `/home/gmcquillan/.claude/hooks/mcp-inventory.sh`

**Interfaces:**
- Produces: SessionStart context block consumed by integration-scan skill ("session-start inventory is already in context"). Registered in settings.json by Task 8.

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# SessionStart hook: inject the list of connected MCP servers so
# integration-first thinking is grounded in what is actually available.
out=$(timeout 10 claude mcp list 2>/dev/null | head -40)
if [ -n "$out" ]; then
  printf 'Connected MCP servers (integration-scan starts here):\n%s\n' "$out"
fi
exit 0
```

- [ ] **Step 2: Make executable and test**

Run: `chmod +x /home/gmcquillan/.claude/hooks/mcp-inventory.sh && echo '{}' | /home/gmcquillan/.claude/hooks/mcp-inventory.sh; echo "exit=$?"`
Expected: prints the MCP server list (mem0, qmd, obsidian-vault, claude.ai connectors) followed by `exit=0`. If `claude mcp list` is slow, output may take a few seconds; empty output with `exit=0` is acceptable only outside a configured environment — here it must list servers.

---

### Task 7: Hook — stub-check.sh

**Files:**
- Create: `/home/gmcquillan/.claude/hooks/stub-check.sh`
- Test: manual, in a throwaway repo under the scratchpad (created and torn down in steps below)

**Interfaces:**
- Consumes: hook stdin JSON fields `session_id`, `stop_hook_active` (Claude Code hook contract); baseline files under `/home/gmcquillan/.claude/cache/stub-baselines/`.
- Produces: two modes — `baseline` (SessionStart) records HEAD; `check` (Stop) exits 2 with stderr guidance when added lines contain silent markers. Registered by Task 8.

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Completion-integrity hook ("done means done").
#   stub-check.sh baseline  — SessionStart: record HEAD for this session
#   stub-check.sh check     — Stop: block turn if lines added since the
#                             baseline contain silent stub markers.
# Escape hatch: markers written as "TODO(tracked): <ref>" pass.
set -u
mode="${1:-check}"
input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
dir="$HOME/.claude/cache/stub-baselines"

# Outside a git repo there is nothing to diff — no-op.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

if [ "$mode" = "baseline" ]; then
  mkdir -p "$dir"
  [ -n "$sid" ] && git rev-parse HEAD 2>/dev/null > "$dir/$sid"
  exit 0
fi

# check mode. Never re-block a continuation triggered by this hook.
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0

base=""
[ -n "$sid" ] && base=$(cat "$dir/$sid" 2>/dev/null)
if [ -z "$base" ] || ! git cat-file -e "$base" 2>/dev/null; then
  base=$(git rev-parse HEAD 2>/dev/null) || exit 0
fi

pattern='\b(TODO|FIXME|XXX|HACK)\b|unimplemented!|todo!\(\)|NotImplementedError|[Nn]ot[ _-]?[Ii]mplemented|(#|//)[[:space:]]*stub\b'

hits=$(
  {
    # Lines added since the session baseline (committed or not).
    git diff "$base" --unified=0 2>/dev/null | grep -E '^\+[^+]' | grep -vE '^\+\+\+'
    # Untracked files are invisible to diff — grep them directly.
    git ls-files --others --exclude-standard -z 2>/dev/null \
      | xargs -0 -r grep -HnE "$pattern" -- 2>/dev/null
  } | grep -E "$pattern" | grep -v 'TODO(tracked):'
)

if [ -n "$hits" ]; then
  {
    echo "BLOCKED — silent incompleteness markers were added this session:"
    echo "$hits" | head -20
    echo ""
    echo "Per 'done means done' (CLAUDE.md principle 5): implement each of"
    echo "these before finishing, or convert to 'TODO(tracked): <issue/task"
    echo "ref>' AND surface it in your final summary."
    echo "To locate: git diff $base | grep -nE '<marker>'"
  } >&2
  exit 2
fi
exit 0
```

- [ ] **Step 2: Make executable; set up test repo**

Run:
```bash
chmod +x /home/gmcquillan/.claude/hooks/stub-check.sh
T=/tmp/claude-1000/-home-gmcquillan/f07a2cb1-51f6-46b9-b67f-ba5cf0d844b0/scratchpad/stubtest
rm -rf "$T" && mkdir -p "$T" && cd "$T" && git init -q && git commit -q --allow-empty -m init
echo '{"session_id":"stubtest","stop_hook_active":false}' > input.json
git add input.json && git commit -qm base
```
Expected: exits 0, repo created with one committed file.

- [ ] **Step 3: Test — baseline mode records HEAD**

Run: `cd "$T" && /home/gmcquillan/.claude/hooks/stub-check.sh baseline < input.json; echo "exit=$?"; diff <(git rev-parse HEAD) /home/gmcquillan/.claude/cache/stub-baselines/stubtest && echo BASELINE-OK`
Expected: `exit=0` then `BASELINE-OK`.

- [ ] **Step 4: Test — clean tree passes**

Run: `cd "$T" && /home/gmcquillan/.claude/hooks/stub-check.sh check < input.json; echo "exit=$?"`
Expected: `exit=0`, no output.

- [ ] **Step 5: Test — committed TODO after baseline blocks**

Run:
```bash
cd "$T" && printf 'def f():\n    pass  # TODO finish\n' > a.py && git add a.py && git commit -qm todo
/home/gmcquillan/.claude/hooks/stub-check.sh check < input.json; echo "exit=$?"
```
Expected: stderr beginning `BLOCKED — silent incompleteness markers...` including the `TODO finish` line; `exit=2`. (This proves the baseline catches markers even after they're committed — plain diff-vs-HEAD would miss this.)

- [ ] **Step 6: Test — TODO(tracked): passes; untracked FIXME blocks**

Run:
```bash
cd "$T" && sed -i 's/TODO finish/TODO(tracked): PROJ-123 finish/' a.py && git commit -qam tracked
/home/gmcquillan/.claude/hooks/stub-check.sh check < input.json; echo "tracked-exit=$?"
echo '// FIXME broken' > new.js
/home/gmcquillan/.claude/hooks/stub-check.sh check < input.json; echo "untracked-exit=$?"
```
Expected: `tracked-exit=0`, then BLOCKED output naming `new.js` and `untracked-exit=2`.

- [ ] **Step 7: Test — stop_hook_active and non-git no-ops**

Run:
```bash
cd "$T" && echo '{"session_id":"stubtest","stop_hook_active":true}' | /home/gmcquillan/.claude/hooks/stub-check.sh check; echo "active-exit=$?"
cd /tmp && echo '{"session_id":"x","stop_hook_active":false}' | /home/gmcquillan/.claude/hooks/stub-check.sh check; echo "nongit-exit=$?"
```
Expected: `active-exit=0` and `nongit-exit=0` (no output). NOTE: if /tmp is inside a git repo on this machine (it isn't, but verify), use another non-repo dir.

- [ ] **Step 8: Tear down**

Run: `rm -rf "$T" /home/gmcquillan/.claude/cache/stub-baselines/stubtest`
Expected: silence.

---

### Task 8: settings.json — model + hook registration

**Files:**
- Modify: `/home/gmcquillan/.claude/settings.json` (currently 20 lines)

**Interfaces:**
- Consumes: hook scripts from Tasks 6–7 at their absolute paths.
- Produces: default model `opus`; SessionStart runs mcp-inventory then stub-check baseline; Stop runs stub-check check.

- [ ] **Step 1: Back up, then write the new settings.json**

Run first: `cp /home/gmcquillan/.claude/settings.json /home/gmcquillan/.claude/backups/settings.json.pre-fable-harness`

Then write (preserving every existing key except `model`):

```json
{
  "attribution": {
    "commit": "",
    "pr": ""
  },
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true,
    "rust-analyzer-lsp@claude-plugins-official": true,
    "frontend-design@claude-plugins-official": true,
    "claude-seo@agricidaniel-claude-seo": true
  },
  "extraKnownMarketplaces": {
    "agricidaniel-claude-seo": {
      "source": {
        "source": "github",
        "repo": "AgriciDaniel/claude-seo"
      }
    }
  },
  "tui": "fullscreen",
  "claude code experimental agent teams": true,
  "model": "opus",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/home/gmcquillan/.claude/hooks/mcp-inventory.sh",
            "timeout": 15
          },
          {
            "type": "command",
            "command": "/home/gmcquillan/.claude/hooks/stub-check.sh baseline"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/home/gmcquillan/.claude/hooks/stub-check.sh check"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Validate**

Run: `jq -e '.model == "opus" and (.hooks.SessionStart[0].hooks | length == 2) and (.hooks.Stop[0].hooks[0].command | contains("stub-check"))' /home/gmcquillan/.claude/settings.json`
Expected: `true` (jq exit 0). Any parse error means the file is malformed — restore from the backup and re-edit.

---

### Task 9: Workflow scripts

**Files:**
- Create: `/home/gmcquillan/.claude/workflows/judge-panel.js`
- Create: `/home/gmcquillan/.claude/workflows/system-map.js`
- Create: `/home/gmcquillan/.claude/workflows/migration-sweep.js`

**Interfaces:**
- Consumes: agent type `skeptic` (Task 2) via `agentType` in migration-sweep.
- Produces: workflow names `judge-panel`, `system-map`, `migration-sweep` referenced by fan-out and creative-exploration skills.

Constraints for all three (Workflow tool contract): `export const meta` is a pure literal; no `Date.now()`, `Math.random()`, or argless `new Date()`; no TypeScript syntax; no filesystem/Node APIs; barriers only where a stage needs ALL prior results.

- [ ] **Step 1: Write judge-panel.js**

```js
export const meta = {
  name: 'judge-panel',
  description: 'Develop divergent design approaches in parallel, score with an Opus judge panel, synthesize a recommendation',
  whenToUse: 'High-stakes design decisions with more than one plausible shape. args: {question: string, constraints?: string[], lenses?: string[]} or a plain question string.',
  phases: [
    { title: 'Develop', detail: 'one Sonnet agent per lens develops an approach' },
    { title: 'Judge', detail: 'three Opus judges score all approaches through distinct lenses', model: 'opus' },
    { title: 'Synthesize', detail: 'graft best runner-up ideas onto the winner', model: 'opus' },
  ],
}

const question = typeof args === 'string' ? args : args && args.question
if (!question) throw new Error('args.question required: the design question to explore')
const constraints = ((args && args.constraints) || []).map(c => `- ${c}`).join('\n')
  || '- none stated; derive binding constraints from repo context and state your assumptions'
const lenses = (args && args.lenses) || [
  'data-first: get the schema and data flow right; logic follows',
  'integration-first: compose existing services, tools, and libraries; write only glue',
  'subtraction: solve by removing or reshaping something instead of adding a new system',
]

const APPROACH = {
  type: 'object',
  properties: {
    name: { type: 'string' },
    summary: { type: 'string' },
    design: { type: 'string', description: 'architecture, key components, data flow, failure handling' },
    tradeoffs: { type: 'string' },
  },
  required: ['name', 'summary', 'design', 'tradeoffs'],
}

phase('Develop')
// Barrier justified: every judge must see ALL approaches.
const approaches = (await parallel(lenses.map((lens, i) => () =>
  agent(
    `Design question: ${question}\n\nBinding constraints:\n${constraints}\n\n` +
    `Develop ONE complete approach through this lens ONLY: ${lens}\n` +
    `Steelman it as its advocate. Ground it in the actual codebase where you can. ` +
    `Include architecture, key components, data flow, failure handling, and honest tradeoffs.`,
    { label: `develop:${i + 1}`, phase: 'Develop', model: 'sonnet', schema: APPROACH }
  )
))).filter(Boolean)
if (approaches.length < 2) throw new Error(`only ${approaches.length} approach(es) developed; need 2+ to judge`)
log(`${approaches.length} approaches developed: ${approaches.map(a => a.name).join(' | ')}`)

const SCORES = {
  type: 'object',
  properties: {
    scores: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          approach: { type: 'string' },
          score: { type: 'number' },
          reasoning: { type: 'string' },
        },
        required: ['approach', 'score', 'reasoning'],
      },
    },
    ranking: { type: 'array', items: { type: 'string' } },
  },
  required: ['scores', 'ranking'],
}
const approachText = approaches.map(a =>
  `## ${a.name}\n${a.summary}\n\n${a.design}\n\nTradeoffs: ${a.tradeoffs}`).join('\n\n')

phase('Judge')
const judgeLenses = [
  'simplicity and maintainability',
  'robustness under change and failure',
  'leverage of existing systems and integration cost',
]
// Barrier justified: synthesis needs every verdict.
const verdicts = (await parallel(judgeLenses.map(jl => () =>
  agent(
    `Judge these competing approaches to: ${question}\nConstraints:\n${constraints}\n\n${approachText}\n\n` +
    `Score each approach 1-10 STRICTLY through the lens of: ${jl}. ` +
    `Justify every score in 1-2 sentences and rank the approaches.`,
    { label: `judge:${jl.split(' ')[0]}`, phase: 'Judge', model: 'opus', schema: SCORES }
  )
))).filter(Boolean)

phase('Synthesize')
const synthesis = await agent(
  `Design question: ${question}\nConstraints:\n${constraints}\n\nApproaches:\n${approachText}\n\n` +
  `Judge verdicts (three lenses):\n${JSON.stringify(verdicts, null, 2)}\n\n` +
  `Pick the winner by argument (do not average across lenses). Then graft onto it the best ` +
  `individual ideas from the non-winning approaches. Deliver: winner + rationale, the grafts, ` +
  `remaining risks, and a concrete next step.`,
  { label: 'synthesize', phase: 'Synthesize', model: 'opus' }
)
return { approaches, verdicts, synthesis }
```

- [ ] **Step 2: Write system-map.js**

```js
export const meta = {
  name: 'system-map',
  description: 'Map subsystems with parallel scouts, then merge into one system map highlighting cross-subsystem integration points',
  whenToUse: 'Onboarding a repo or preparing a cross-cutting change. args: {paths: string[], focus?: string} or a plain array of paths.',
  phases: [
    { title: 'Scout', detail: 'one Sonnet scout per subsystem path' },
    { title: 'Merge', detail: 'combine maps; surface cross-subsystem contracts and mismatches', model: 'opus' },
  ],
}

const paths = Array.isArray(args) ? args : args && args.paths
if (!paths || !paths.length) throw new Error('args.paths required: list of subsystem directories to map')
const focus = args && args.focus ? `\nPay special attention to: ${args.focus}` : ''

const MAP = {
  type: 'object',
  properties: {
    subsystem: { type: 'string' },
    entryPoints: { type: 'array', items: { type: 'string' }, description: 'each with file:line' },
    dataFlow: { type: 'string' },
    integrationSurfaces: { type: 'array', items: { type: 'string' }, description: 'APIs, DBs, queues, env/config keys, flags' },
    dependsOn: { type: 'array', items: { type: 'string' } },
    hollowSpots: { type: 'array', items: { type: 'string' }, description: 'stubs/facades with file:line; empty if none' },
  },
  required: ['subsystem', 'entryPoints', 'dataFlow', 'integrationSurfaces', 'dependsOn', 'hollowSpots'],
}

phase('Scout')
// Barrier justified: the merge needs every subsystem map to find cross-cutting contracts.
const maps = (await parallel(paths.map(p => () =>
  agent(
    `Map the subsystem rooted at: ${p}${focus}\n` +
    `Read-only. Identify: entry points (file:line); primary data flow; integration surfaces ` +
    `(external APIs, databases, queues, env/config keys, feature flags); internal dependencies ` +
    `(imports in and out); and hollow spots (endpoints returning canned data, swallowed errors, ` +
    `TODO/FIXME markers, flags wired to nothing). Cite file:line for every claim.`,
    { label: `scout:${p}`, phase: 'Scout', model: 'sonnet', schema: MAP }
  )
))).filter(Boolean)
if (!maps.length) throw new Error('all scouts failed; nothing to merge')
log(`${maps.length}/${paths.length} subsystems mapped`)

phase('Merge')
const merged = await agent(
  `Merge these subsystem maps into ONE system map:\n${JSON.stringify(maps, null, 2)}\n\n` +
  `Deliver: (1) a compact component diagram in text; (2) cross-subsystem integration points — ` +
  `shared data stores, queues, APIs, and which side owns each contract; (3) mismatches, where one ` +
  `subsystem's expectation and another's behavior disagree; (4) the consolidated hollow-spots list ` +
  `ranked by risk; (5) the 3 places a cross-cutting change is most likely to break something.`,
  { label: 'merge', phase: 'Merge', model: 'opus' }
)
return { subsystems: maps, systemMap: merged, unmapped: paths.length - maps.length }
```

- [ ] **Step 3: Write migration-sweep.js**

```js
export const meta = {
  name: 'migration-sweep',
  description: 'Discover every site matching a pattern, transform each file in parallel (one agent per file), adversarially verify each change, report coverage',
  whenToUse: 'Mechanical migrations across many files. args: {pattern: string, instruction: string, verifyCmd?: string}',
  phases: [
    { title: 'Discover', detail: 'enumerate affected files' },
    { title: 'Transform', detail: 'one Sonnet agent per file; disjoint ownership, no conflicts' },
    { title: 'Verify', detail: 'skeptic agent per changed file' },
  ],
}

const { pattern, instruction, verifyCmd } = args || {}
if (!pattern || !instruction) throw new Error('args.pattern and args.instruction are both required')

phase('Discover')
const SITES = {
  type: 'object',
  properties: { files: { type: 'array', items: { type: 'string' } } },
  required: ['files'],
}
const found = await agent(
  `Find every file in this repo matching the discovery pattern below (use grep/glob as appropriate; ` +
  `exclude .git, node_modules, vendor, build artifacts). Return the deduplicated list of ` +
  `repo-relative paths. Do NOT modify anything.\n\nPattern: ${pattern}`,
  { label: 'discover', phase: 'Discover', model: 'sonnet', schema: SITES }
)
const files = (found && found.files) || []
if (!files.length) return { transformed: 0, results: [], note: 'no sites matched the pattern' }
log(`${files.length} files to transform`)

const RESULT = {
  type: 'object',
  properties: {
    file: { type: 'string' },
    changed: { type: 'boolean' },
    summary: { type: 'string' },
  },
  required: ['file', 'changed', 'summary'],
}
const VERDICT = {
  type: 'object',
  properties: { ok: { type: 'boolean' }, problems: { type: 'string' } },
  required: ['ok', 'problems'],
}

// Pipeline, not barrier: each file's verify starts the moment its transform lands.
// Isolation comes from disjoint ownership - each agent may touch ONLY its one file.
const results = await pipeline(
  files,
  f => agent(
    `Apply this transform to ${f} — and ONLY this file; do not touch any other file:\n` +
    `${instruction}\n` +
    (verifyCmd ? `Afterwards run: ${verifyCmd}\nIt must pass; if it fails, fix your change until it does.\n` : '') +
    `If the file needs no change, report changed=false. Never leave TODO/stub shortcuts.`,
    { label: `transform:${f}`, phase: 'Transform', model: 'sonnet', schema: RESULT }
  ),
  (r, f) => !r || !r.changed ? r : agent(
    `A migration was applied to ${f}. Instruction: ${instruction}\nAgent's summary: ${r.summary}\n` +
    `Adversarially verify: read the file, hunt for missed sites within it, broken callers, and ` +
    `TODO/stub shortcuts. Try to REFUTE the claim that this change is complete and correct.`,
    { label: `verify:${f}`, phase: 'Verify', agentType: 'skeptic', schema: VERDICT }
  ).then(v => ({ ...r, verdict: v }))
)

const done = results.filter(Boolean)
const failed = done.filter(r => r.verdict && !r.verdict.ok)
// No silent caps: name what dropped out.
const dropped = files.filter((f, i) => !results[i])
if (dropped.length) log(`WARNING: ${dropped.length} file(s) dropped by errors: ${dropped.join(', ')}`)
return {
  transformed: done.filter(r => r.changed).length,
  unchanged: done.filter(r => !r.changed).length,
  failedVerify: failed,
  dropped,
  results: done,
}
```

- [ ] **Step 4: Syntax-check all three (corrected during execution)**

The workflow runtime wraps each script body in its own async function, which is
what makes top-level `return` and `await` legal in these files. A plain
`node --check` on a verbatim copy therefore FAILS (`Illegal return statement`)
— that is expected, not a defect in the scripts. Validate by mimicking the
runtime's wrapping on scratch copies; never modify the installed files:

```bash
S=/tmp/claude-1000/-home-gmcquillan/f07a2cb1-51f6-46b9-b67f-ba5cf0d844b0/scratchpad
for w in judge-panel system-map migration-sweep; do
  { echo 'async function __wf(args, agent, parallel, pipeline, phase, log, budget, workflow) {'
    sed 's/^export const meta = /const meta = /' "/home/gmcquillan/.claude/workflows/$w.js"
    echo '}'
  } > "$S/$w-check.mjs"
  node --check "$S/$w-check.mjs" && echo "$w OK"
done
```
Expected: `judge-panel OK`, `system-map OK`, `migration-sweep OK`.

---

### Task 10: End-to-end smoke test

**Files:** none created — verification only.

- [ ] **Step 1: Full manifest check**

Run:
```bash
for f in CLAUDE.md skills/systems-mapping/SKILL.md skills/integration-scan/SKILL.md \
  skills/creative-exploration/SKILL.md skills/fan-out/SKILL.md skills/stub-audit/SKILL.md \
  agents/scout.md agents/integrator.md agents/skeptic.md agents/judge.md \
  workflows/judge-panel.js workflows/system-map.js workflows/migration-sweep.js \
  hooks/mcp-inventory.sh hooks/stub-check.sh settings.json; do
  [ -s "/home/gmcquillan/.claude/$f" ] && echo "OK  $f" || echo "MISS $f"
done
```
Expected: 16 × `OK`, zero `MISS`.

- [ ] **Step 2: Hook executability + settings sanity**

Run: `test -x /home/gmcquillan/.claude/hooks/mcp-inventory.sh -a -x /home/gmcquillan/.claude/hooks/stub-check.sh && jq -e .hooks /home/gmcquillan/.claude/settings.json > /dev/null && echo HOOKS-OK`
Expected: `HOOKS-OK`.

- [ ] **Step 3: Live-session checks (requires new session — hand to user)**

Report to the user that these three checks need a fresh `claude` session, since settings and hooks load at startup:
1. Session starts showing the MCP inventory block from the SessionStart hook, and `/model` shows Opus as default.
2. In any git repo: ask Claude to "add a TODO comment to a file and finish" — the Stop hook must block with the BLOCKED message; then `TODO(tracked): TEST-1` must pass. Delete the test comment afterwards.
3. `/fan-out` and `/stub-audit` appear as invocable skills.

Current session caveat: this session was started before the hooks existed, so the Stop hook is NOT active here — expected, not a bug.

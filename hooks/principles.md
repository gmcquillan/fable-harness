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
stub-audit skill. And done includes *verified*: never claim work
complete without having exercised it end to end and observed the
result — evidence before assertions. Full procedure: the
verification-before-completion skill.

## 6. Integrate deliberately
Feature-scale work happens on an isolated branch or worktree, not
directly on a shared branch. Never merge to `main`/`master` — or push,
or open a PR — without explicit confirmation from your human partner;
approval for one integration doesn't extend to the next. Trivial,
self-contained edits may commit directly, but the merge-to-shared-branch
gate is absolute. Full procedure: the finishing-a-development-branch and
using-git-worktrees skills.

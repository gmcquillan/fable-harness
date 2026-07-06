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
this shape — it ships with the fan-out skill (`workflows/judge-panel.js`
under that skill's base directory, invoked via Workflow scriptPath).

## Anti-patterns

- Three variants of one idea ("Postgres, but with different indexes") —
  that's tuning, not divergence.
- Scoring on elegance when the binding constraint is the deadline.
- Skipping this because the request "obviously" implies a design — the
  requester's framing is itself one of the lenses, not the answer.

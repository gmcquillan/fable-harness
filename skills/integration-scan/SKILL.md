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

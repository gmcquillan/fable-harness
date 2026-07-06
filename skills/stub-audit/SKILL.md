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

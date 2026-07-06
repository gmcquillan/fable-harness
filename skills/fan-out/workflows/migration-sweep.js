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

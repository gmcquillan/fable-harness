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
const rawMaps = await parallel(paths.map(p => () =>
  agent(
    `Map the subsystem rooted at: ${p}${focus}\n` +
    `Read-only. Identify: entry points (file:line); primary data flow; integration surfaces ` +
    `(external APIs, databases, queues, env/config keys, feature flags); internal dependencies ` +
    `(imports in and out); and hollow spots (endpoints returning canned data, swallowed errors, ` +
    `TODO/FIXME markers, flags wired to nothing). Cite file:line for every claim.`,
    { label: `scout:${p}`, phase: 'Scout', model: 'sonnet', schema: MAP }
  )
))
const maps = rawMaps.filter(Boolean)
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
const unmappedPaths = paths.filter((p, i) => !rawMaps[i])
if (unmappedPaths.length) log(`WARNING: ${unmappedPaths.length} subsystem(s) failed to map: ${unmappedPaths.join(', ')}`)
return { subsystems: maps, systemMap: merged, unmapped: unmappedPaths }

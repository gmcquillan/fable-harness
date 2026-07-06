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
if (!verdicts.length) throw new Error('all judges failed; cannot synthesize')

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

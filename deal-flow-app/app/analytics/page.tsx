export default function AnalyticsPage() {
  // Placeholder metrics. Replace with real data fetching in future.
  const pipelineStages = [
    { stage: 'Lead', count: 3 },
    { stage: 'Discovery', count: 1 },
    { stage: 'Sourcing', count: 2 },
    { stage: 'Shortlist', count: 1 },
    { stage: 'Touring', count: 0 },
    { stage: 'LOI', count: 1 },
    { stage: 'Negotiation', count: 0 },
    { stage: 'Legal', count: 0 },
    { stage: 'Won', count: 0 },
    { stage: 'Lost', count: 0 },
  ]
  const kpis = [
    { label: 'Avg Time to LOI', value: '45 days' },
    { label: 'Win Rate', value: '25%' },
    { label: 'Concession Value Captured', value: '$12.00/RSF' },
  ]
  return (
    <div className="page p-4">
      <h1 className="text-xl font-bold mb-4">Analytics Dashboard</h1>
      <div className="grid grid-cols-3 gap-4 mb-6">
        {kpis.map(k => (
          <div key={k.label} className="bg-white shadow p-4 rounded">
            <div className="text-gray-500 text-sm">{k.label}</div>
            <div className="text-2xl font-semibold">{k.value}</div>
          </div>
        ))}
      </div>
      <h2 className="text-lg font-semibold mb-2">Pipeline by Stage</h2>
      <div className="grid grid-cols-5 gap-4">
        {pipelineStages.map(ps => (
          <div key={ps.stage} className="bg-white shadow p-4 rounded text-center">
            <div className="text-gray-600 text-sm">{ps.stage}</div>
            <div className="text-xl font-bold">{ps.count}</div>
          </div>
        ))}
      </div>
    </div>
  )
}

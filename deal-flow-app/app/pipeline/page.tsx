import Link from 'next/link'
import { prisma } from '@/lib/db'
import { STAGES } from '@/lib/stage'

export default async function Pipeline() {
  const deals = await prisma.deal.findMany({ include: { client: true, owner: true }, orderBy: { createdAt: 'desc' } });
  const grouped: Record<string, any[]> = Object.fromEntries(STAGES.map(s => [s.key, []]));
  for (const d of deals) { (grouped[d.stage] ||= []).push(d); }
  return (
    <div className="page">
      <h1>Pipeline</h1>
      <div className="grid grid-cols-1 md:grid-cols-3 xl:grid-cols-5 gap-4">
        {STAGES.filter(s => !['won','lost'].includes(s.key)).map(s => (
          <div key={s.key} className="card">
            <div className="flex items-center justify-between mb-2">
              <h2>{s.label}</h2>
              <span className="text-xs text-slate-500">{(grouped[s.key]?.length || 0)}</span>
            </div>
            <div className="flex flex-col gap-2">
              {(grouped[s.key] || []).map((d: any) => (
                <Link key={d.id} href={`/deals/${d.id}`} className="block rounded border border-slate-200 p-3 hover:bg-slate-50">
                  <div className="font-medium">{d.title}</div>
                  <div className="text-xs text-slate-500">{d.client?.name} • {Math.round((d.probability ?? 0)*100)}%</div>
                </Link>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

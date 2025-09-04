import Link from 'next/link'
import { prisma } from '@/lib/db'

export default async function ShortlistsPage() {
  const lists = await prisma.shortlist.findMany({ include: { deal: { include: { client: true } }, items: true }, orderBy: { id: 'asc' } })
  return (
    <div className="page">
      <h1>Shortlists</h1>
      <div className="grid md:grid-cols-2 gap-4">
        {lists.map(sl => (
          <div key={sl.id} className="card">
            <div className="font-medium">{sl.deal?.title}</div>
            <div className="text-sm text-slate-500">{sl.deal?.client?.name} • {sl.items.length} item(s)</div>
            <div className="mt-3 flex gap-3">
              <Link className="underline" href={`/shortlists/${sl.id}/compare`}>Open Compare</Link>
              <Link className="underline" href={`/deals/${sl.dealId}`}>Go to Deal</Link>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

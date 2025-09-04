import Link from 'next/link'
import { prisma } from '@/lib/db'

export default async function ToursPage() {
  const tours = await prisma.tour.findMany({ include: { deal: { include: { client: true } } }, orderBy: { tourDate: 'desc' } })
  return (
    <div className="page">
      <h1>Tours</h1>
      <div className="grid md:grid-cols-2 gap-4">
        {tours.map(t => (
          <div key={t.id} className="card">
            <div className="font-medium">{t.deal?.title}</div>
            <div className="text-sm text-slate-500">{t.deal?.client?.name} • {t.tourDate ? new Date(t.tourDate).toLocaleDateString() : 'No Date'}</div>
            <div className="mt-3 flex gap-3 items-center">
              <Link className="underline" href={`/tours/${t.id}/print`}>Print Tour Book</Link>
              <form action={`/api/tours/${t.id}/optimize`} method="post">
                <button className="px-3 py-1 rounded bg-slate-700 text-white text-xs" formAction={`/api/tours/${t.id}/optimize`}>Optimize Route</button>
              </form>
              <Link className="underline" href={`/deals/${t.dealId}`}>Go to Deal</Link>
            </div>
          </div>
        ))}
        {tours.length === 0 && <div className="text-slate-500">No tours yet.</div>}
      </div>
    </div>
  )
}

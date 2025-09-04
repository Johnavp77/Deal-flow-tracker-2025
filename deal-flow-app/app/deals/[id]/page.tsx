import { prisma } from '@/lib/db'
import Link from 'next/link'

export default async function DealDetail({ params }: { params: { id: string }}) {
  const deal = await prisma.deal.findUnique({
    where: { id: params.id },
    include: { client: true, owner: true, requirements: true, shortlists: true, tours: true, lois: true }
  });
  if (!deal) return <div className="page">Not found</div>;
  return (
    <div className="page">
      <h1>{deal.title}</h1>
      <div className="grid md:grid-cols-2 gap-4">
        <div className="card">
          <h2>Basics</h2>
          <div className="text-sm">Client: {deal.client?.name}</div>
          <div className="text-sm">Owner: {deal.owner?.fullName}</div>
          <div className="text-sm">Stage: {deal.stage}</div>
          <div className="text-sm">Probability: {Math.round((deal.probability ?? 0)*100)}%</div>
        </div>
        <div className="card">
          <h2>Requirements</h2>
          <div className="text-sm">RSF: {deal.requirements?.rsfMin}–{deal.requirements?.rsfMax}</div>
          <div className="text-sm">Term (mo): {deal.requirements?.termMonths}</div>
          <div className="text-sm">Lease Type: {deal.requirements?.leaseType}</div>
          <div className="text-sm">Submarkets: {deal.requirements?.submarkets?.join(', ')}</div>
        </div>
      </div>

      <div className="grid md:grid-cols-3 gap-4 mt-6">
        <div className="card"><h2>Shortlists</h2>{deal.shortlists.length} shortlist(s)</div>
        <div className="card"><h2>Tours</h2>{deal.tours.length} tour(s)</div>
        <div className="card"><h2>LOIs</h2>{deal.lois.length} LOI(s)</div>
      </div>

      <div className="mt-6 flex gap-4">
        <Link href={`/deals/${deal.id}/loi-builder`} className="underline">Open LOI Builder</Link>
        <Link href="/shortlists" className="underline">Go to Shortlists</Link>
      </div>
    </div>
  )
}

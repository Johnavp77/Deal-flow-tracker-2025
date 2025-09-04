import Link from 'next/link'
import { prisma } from '@/lib/db'

export default async function PropertiesPage() {
  const props = await prisma.property.findMany({ orderBy: { address1: 'asc' } })
  return (
    <div className="page">
      <h1>Properties</h1>
      <div className="grid md:grid-cols-2 gap-4">
        {props.map(p => (
          <div key={p.id} className="card">
            <div className="font-medium">{p.address1}, {p.city}</div>
            <div className="text-sm text-slate-500">{p.submarket || '-'} • {p.propertyType || '-'}</div>
            <div className="mt-3 flex gap-3">
              <Link className="underline" href={`/properties/${p.id}/photos`}>Photos</Link>
            </div>
          </div>
        ))}
        {props.length === 0 && <div className="text-slate-500">No properties found.</div>}
      </div>
    </div>
  )
}

import { prisma } from '@/lib/db'
import PhotoUploader from '@/components/PhotoUploader'
import Link from 'next/link'

export default async function PropertyPhotos({ params }: { params: { id: string } }) {
  const p = await prisma.property.findUnique({ where: { id: params.id } })
  if (!p) return <div className="page">Property not found</div>
  const photos = await prisma.document.findMany({ where: { entityType: 'Property', entityId: p.id, kind: 'photo' }, orderBy: { createdAt: 'desc' } })

  return (
    <div className="page">
      <div className="flex items-center justify-between">
        <h1>Photos — {p.address1}, {p.city}</h1>
        <div className="flex gap-3 items-center">
          <PhotoUploader propertyId={p.id} />
          <Link className="underline" href="/properties">Back to Properties</Link>
        </div>
      </div>
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mt-4">
        {photos.map(ph => (
          <div key={ph.id} className="border rounded overflow-hidden">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={ph.fileUrl} alt="" className="w-full h-48 object-cover" />
            <div className="p-2 text-xs text-slate-500">{ph.fileUrl}</div>
          </div>
        ))}
        {photos.length === 0 && <div className="text-slate-500">No photos yet.</div>}
      </div>
    </div>
  )
}

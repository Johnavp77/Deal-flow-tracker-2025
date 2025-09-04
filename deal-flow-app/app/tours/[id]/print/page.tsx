import { prisma } from '@/lib/db'
import PrintButton from './PrintButton'
import dynamic from 'next/dynamic'
const MapInset = dynamic(() => import('@/components/MapInset'), { ssr: false })
const Montage = dynamic(() => import('@/components/Montage'), { ssr: false })
import OptimizeButton from '../OptimizeButton'
import PdfButton from '@/components/PdfButton'

function mapboxStatic(lat?: number|null, lng?: number|null) {
  const token = process.env.NEXT_PUBLIC_MAPBOX_TOKEN
  if (!lat || !lng || !token) return null
  return `https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/pin-s+004B8D(${lng},${lat})/${lng},${lat},15/800x400@2x?access_token=${token}`
}

export default async function TourPrint({ params }: { params: { id: string } }) {
  const tour = await prisma.tour.findUnique({
    where: { id: params.id },
    include: { deal: { include: { client: true } }, stops: { include: { property: true, availability: true } } }
  })
  if (!tour) return <div className="page">Tour not found</div>
  const stops = [...tour.stops].sort((a,b)=>(a.stopOrder??0)-(b.stopOrder??0))

  const propertyIds = stops.map(s => s.propertyId)
  const photos = await prisma.document.findMany({ where: { entityType: 'Property', entityId: { in: propertyIds }, kind: 'photo' }, orderBy: { createdAt: 'desc' } })
  const photosByProp = new Map<string, string[]>()
  for (const ph of photos) {
    const arr = photosByProp.get(ph.entityId) || []
    arr.push(ph.fileUrl)
    photosByProp.set(ph.entityId, arr)
  }
  // Build montage tiles (prefer uploaded photos, else map static, else nothing)
  const tiles: { src: string, alt?: string }[] = []
  for (const s of stops) {
    const p = s.property
    const imgs = photosByProp.get(p.id) || []
    if (imgs[0]) {
      tiles.push({ src: imgs[0], alt: `${p.address1}` })
    } else {
      const map = mapboxStatic(Number(p.lat), Number(p.lng))
      if (map) tiles.push({ src: map, alt: `${p.address1}` })
    }
  }

  return (
    <div className="page print:!p-0">
      <div className="no-print flex justify-between mb-4 items-center">
        <div className="flex gap-2">
          <PrintButton />
          <PdfButton path={`/tours/${tour.id}/print`} filename={`tour_${tour.id}.pdf`} />
          <OptimizeButton tourId={tour.id} />
        </div>
        <a href="../" className="underline">Back to Tour</a>
      </div>

      {/* COVER PAGE */}
      <header className="flex items-center gap-4 mb-4 print:mb-0">
        <img src="/branding/wra-logo.svg" alt="WRA" className="h-12" />
        <div>
          <div className="text-sm text-slate-500">Tour Book</div>
          <div className="text-lg font-semibold">{tour.deal.client?.name} — {tour.deal.title}</div>
          <div className="text-sm">{tour.tourDate ? new Date(tour.tourDate).toLocaleDateString() : 'TBD'}</div>
        </div>
      </header>

      {tiles.length ? (
        <section className="card print:shadow-none print:border-0 print:rounded-none">
          <h2>Properties Preview</h2>
          {/* @ts-expect-error Async/CSR */}
          <Montage tiles={tiles} />
        </section>
      ) : null}

      <section className="mt-6 card print:shadow-none print:border-0 print:rounded-none">
        <h2>Itinerary</h2>
        <ol className="list-decimal pl-6">
          {stops.map((s, i) => (
            <li key={s.id} className="mb-2">
              <b>Stop {s.stopOrder ?? (i+1)}:</b> {s.property.address1}, {s.property.city}, {s.property.state} {s.property.postalCode}
              {s.availability?.suite ? <> — <i>{s.availability.suite}</i></> : null}
            </li>
          ))}
        </ol>
      </section>

      {stops.map((s, i) => (
        <section key={s.id} className="mt-6 card break-before-page print:break-before-page">
          <h2>Property {i+1}: {s.property.address1}</h2>
          <div className="grid md:grid-cols-2 gap-4">
            <div>
              <div className="text-sm"><b>Address:</b> {s.property.address1}, {s.property.city}, {s.property.state} {s.property.postalCode}</div>
              <div className="text-sm"><b>Submarket:</b> {s.property.submarket ?? '-'}</div>
              <div className="text-sm"><b>Type:</b> {s.property.propertyType ?? '-'}</div>
              <div className="text-sm"><b>Building RSF:</b> {s.property.rsfTotal ?? '-'}</div>
            </div>
            <div>
              <div className="text-sm"><b>Suite:</b> {s.availability?.suite ?? '-'}</div>
              <div className="text-sm"><b>RSF:</b> {s.availability?.rsf ?? '-'}</div>
              <div className="text-sm"><b>Asking:</b> {s.availability?.askingRentPsf?.toString() ?? '-'} $/RSF/Yr ({s.availability?.leaseType ?? '-'})</div>
              <div className="text-sm"><b>Ops:</b> {s.availability?.nnnPsf?.toString() ?? s.availability?.opExPsf?.toString() ?? '-'} {s.availability?.nnnPsf ? '(NNN)' : s.availability?.opExPsf ? '(OpEx)' : ''}</div>
              <div className="text-sm"><b>Delivery:</b> {s.availability?.deliveryDate ? new Date(s.availability.deliveryDate).toLocaleDateString() : '-'}</div>
            </div>
          </div>
          <div className="mt-4">
            <div className="font-medium mb-2">Map</div>
            <MapInset lat={Number(s.property.lat)} lng={Number(s.property.lng)} />
          </div>
          <div className="mt-6">
            <div className="font-medium mb-2">Notes</div>
            <div className="h-32 border rounded p-2 text-slate-400">Write-in notes area</div>
          </div>
        </section>
      ))}

      <style jsx global>{`
        @media print {
          .no-print { display: none !important; }
          .card { box-shadow: none !important; border: none !important; border-radius: 0 !important; }
          header { margin-top: 8mm; }
          section { page-break-inside: avoid; }
        }
      `}</style>

      <div className="no-print mt-6 text-xs text-slate-500">
        Tip: add property photos for a richer cover. Upload at <code>/properties/&lt;propertyId&gt;/photos</code>.
      </div>
    </div>
  )
}

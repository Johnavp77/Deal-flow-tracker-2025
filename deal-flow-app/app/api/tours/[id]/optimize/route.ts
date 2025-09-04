import { NextResponse } from 'next/server'
import { prisma } from '@/lib/db'

function dist(a: {lat:number,lng:number}, b: {lat:number,lng:number}) {
  const dx = (a.lng - b.lng) * Math.cos(((a.lat + b.lat)/2) * Math.PI/180)
  const dy = (a.lat - b.lat)
  return Math.sqrt(dx*dx + dy*dy)
}

export async function POST(_: Request, { params }: { params: { id: string }}) {
  const tour = await prisma.tour.findUnique({
    where: { id: params.id },
    include: { stops: { include: { property: true } } }
  })
  if (!tour) return NextResponse.json({ error: 'Tour not found' }, { status: 404 })

  const pts = tour.stops.map(s => ({
    id: s.id,
    lat: Number(s.property.lat ?? NaN),
    lng: Number(s.property.lng ?? NaN),
    hasGeo: s.property.lat !== null && s.property.lng !== null
  }))

  if (pts.some(p => !p.hasGeo)) {
    return NextResponse.json({ error: 'All stops must have lat/lng to optimize.' }, { status: 400 })
  }

  // Nearest Neighbor heuristic starting from first stop by current order (or first array item)
  const stopsSorted = [...tour.stops].sort((a,b)=> (a.stopOrder ?? 0) - (b.stopOrder ?? 0))
  const startId = stopsSorted[0]?.id || tour.stops[0].id
  const remaining = new Map(pts.map(p => [p.id, p]))
  const order: string[] = []
  let current = remaining.get(startId)!
  order.push(current.id); remaining.delete(current.id)
  while (remaining.size) {
    let best: any = null; let bestD = Infinity
    for (const p of remaining.values()) {
      const d = dist(current, p as any)
      if (d < bestD) { bestD = d; best = p }
    }
    order.push(best.id); remaining.delete(best.id); current = best
  }

  // Persist new order 1..N
  for (let i = 0; i < order.length; i++) {
    await prisma.tourStop.update({ where: { id: order[i] }, data: { stopOrder: i+1 } })
  }

  return NextResponse.json({ ok: true, order })
}

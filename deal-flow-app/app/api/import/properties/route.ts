import { NextResponse } from 'next/server'
import { prisma } from '@/lib/db'
import { getDefaultOrgId, toInt, toFloat, normalizePropertyType, normalizeBuildingClass, propKey } from '../utils'

export async function POST(req: Request) {
  const form = await req.formData()
  const file = form.get('file') as File | null
  if (!file) return NextResponse.json({ error: 'No file provided' }, { status: 400 })
  const text = await file.text()
  const Papa = await import('papaparse')
  const parsed = Papa.parse(text, { header: true, skipEmptyLines: true })
  if (parsed.errors.length) return NextResponse.json({ error: parsed.errors[0].message }, { status: 400 })
  const rows = parsed.data as any[]

  const orgId = await getDefaultOrgId()
  let created = 0, updated = 0
  for (const r of rows) {
    const key = propKey(r.address1, r.city, r.state, r.postalCode)
    const existing = await prisma.property.findFirst({
      where: { orgId, address1: r.address1 ?? null, city: r.city ?? null, state: r.state ?? null, postalCode: r.postalCode ?? null }
    })
    const data: any = {
      orgId,
      address1: r.address1 || null,
      city: r.city || null,
      state: r.state || null,
      postalCode: r.postalCode || null,
      submarket: r.submarket || null,
      propertyType: normalizePropertyType(r.propertyType),
      buildingClass: normalizeBuildingClass(r.buildingClass),
      rsfTotal: toInt(r.rsfTotal),
      ownerName: r.ownerName || null,
      sourceUrl: r.sourceUrl || null,
      lat: toFloat(r.lat) as any,
      lng: toFloat(r.lng) as any
    }
    if (existing) {
      await prisma.property.update({ where: { id: existing.id }, data })
      updated++
    } else {
      await prisma.property.create({ data })
      created++
    }
  }
  return NextResponse.json({ ok: true, created, updated })
}

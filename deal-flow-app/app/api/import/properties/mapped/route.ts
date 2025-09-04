import { NextResponse } from 'next/server'
import { z } from 'zod'
import { prisma } from '@/lib/db'
import { requestSchema, pick, toInt, toFloat } from '../../_helpers'
import { getDefaultOrgId, normalizePropertyType, normalizeBuildingClass } from '../../utils'

const propSchema = z.object({
  address1: z.string().min(1, 'address1 is required'),
  city: z.string().min(1, 'city is required'),
  state: z.string().min(1, 'state is required'),
  postalCode: z.string().min(1, 'postalCode is required'),
  submarket: z.string().optional().nullable(),
  propertyType: z.enum(['Office','Industrial','Flex','Lab','Medical','Retail']).optional().nullable(),
  buildingClass: z.enum(['A','B','C']).optional().nullable(),
  rsfTotal: z.number().int().positive().optional().nullable(),
  ownerName: z.string().optional().nullable(),
  sourceUrl: z.string().url().optional().nullable(),
  lat: z.number().optional().nullable(),
  lng: z.number().optional().nullable()
})

export async function POST(req: Request) {
  const body = await req.json()
  const parsed = requestSchema.safeParse(body)
  if (!parsed.success) return NextResponse.json({ error: parsed.error.message }, { status: 400 })
  const { rows, mapping } = parsed.data
  const orgId = await getDefaultOrgId()

  let created = 0, updated = 0, errors: any[] = []
  for (let i = 0; i < rows.length; i++) {
    const r = rows[i]
    const data = {
      address1: String(pick(r, mapping, 'address1') ?? '').trim(),
      city: String(pick(r, mapping, 'city') ?? '').trim(),
      state: String(pick(r, mapping, 'state') ?? '').trim(),
      postalCode: String(pick(r, mapping, 'postalCode') ?? '').trim(),
      submarket: (pick(r, mapping, 'submarket') ?? undefined) as any,
      propertyType: normalizePropertyType(String(pick(r, mapping, 'propertyType') ?? '')) as any,
      buildingClass: normalizeBuildingClass(String(pick(r, mapping, 'buildingClass') ?? '')) as any,
      rsfTotal: toInt(pick(r, mapping, 'rsfTotal')) ?? undefined,
      ownerName: (pick(r, mapping, 'ownerName') ?? undefined) as any,
      sourceUrl: (pick(r, mapping, 'sourceUrl') ?? undefined) as any,
      lat: toFloat(pick(r, mapping, 'lat')) ?? undefined,
      lng: toFloat(pick(r, mapping, 'lng')) ?? undefined
    }
    const safe = propSchema.safeParse(data)
    if (!safe.success) { errors.push({ row: i+1, issues: safe.error.issues.map(x=>x.message) }); continue }

    const existing = await prisma.property.findFirst({ where: { orgId, address1: data.address1, city: data.city, state: data.state, postalCode: data.postalCode } })
    if (existing) { await prisma.property.update({ where: { id: existing.id }, data: { orgId, ...data } }); updated++ }
    else { await prisma.property.create({ data: { orgId, ...data } }); created++ }
  }

  return NextResponse.json({ ok: true, created, updated, errorCount: errors.length, errors })
}

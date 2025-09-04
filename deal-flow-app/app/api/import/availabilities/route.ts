import { NextResponse } from 'next/server'
import { prisma } from '@/lib/db'
import { getDefaultOrgId, toInt, toFloat, toDate } from '../utils'

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
  let created = 0
  for (const r of rows) {
    const property = await prisma.property.findFirst({
      where: { orgId, address1: r.address1 ?? null, city: r.city ?? null, state: r.state ?? null, postalCode: r.postalCode ?? null }
    })
    const propId = property?.id ?? (await prisma.property.create({
      data: { orgId, address1: r.address1 || null, city: r.city || null, state: r.state || null, postalCode: r.postalCode || null }
    })).id

    await prisma.availability.create({
      data: {
        propertyId: propId,
        suite: r.suite || null,
        rsf: toInt(r.rsf),
        floor: r.floor || null,
        condition: r.condition || null,
        deliveryDate: toDate(r.deliveryDate),
        askingRentPsf: toFloat(r.askingRentPsf) as any,
        leaseType: r.leaseType || null,
        opExPsf: toFloat(r.opExPsf) as any,
        baseYear: toInt(r.baseYear),
        nnnPsf: toFloat(r.nnnPsf) as any,
        tiPsf: toFloat(r.tiPsf) as any,
        freeRentMonths: toInt(r.freeRentMonths),
        escalationPct: toFloat(r.escalationPct) as any,
        termMin: toInt(r.termMin),
        termMax: toInt(r.termMax)
      }
    })
    created++
  }
  return NextResponse.json({ ok: true, created })
}

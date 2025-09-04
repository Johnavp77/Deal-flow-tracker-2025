import { NextResponse } from 'next/server'
import { z } from 'zod'
import { prisma } from '@/lib/db'
import { requestSchema, pick, toInt, toFloat, toDate, findOrCreateProperty } from '../../_helpers'
import { getDefaultOrgId } from '../../utils'

const availSchema = z.object({
  address1: z.string().min(1,'address1 required'),
  city: z.string().min(1,'city required'),
  state: z.string().min(1,'state required'),
  postalCode: z.string().min(1,'postalCode required'),
  suite: z.string().optional().nullable(),
  rsf: z.number().int().positive().optional().nullable(),
  floor: z.string().optional().nullable(),
  condition: z.string().optional().nullable(),
  deliveryDate: z.date().optional().nullable(),
  askingRentPsf: z.number().positive().optional().nullable(),
  leaseType: z.string().optional().nullable(),
  opExPsf: z.number().nonnegative().optional().nullable(),
  baseYear: z.number().int().optional().nullable(),
  nnnPsf: z.number().nonnegative().optional().nullable(),
  tiPsf: z.number().nonnegative().optional().nullable(),
  freeRentMonths: z.number().int().nonnegative().optional().nullable(),
  escalationPct: z.number().nonnegative().optional().nullable(),
  termMin: z.number().int().positive().optional().nullable(),
  termMax: z.number().int().positive().optional().nullable()
})

export async function POST(req: Request) {
  const body = await req.json()
  const parsed = requestSchema.safeParse(body)
  if (!parsed.success) return NextResponse.json({ error: parsed.error.message }, { status: 400 })
  const { rows, mapping } = parsed.data
  const orgId = await getDefaultOrgId()

  let created = 0, errors: any[] = []
  for (let i = 0; i < rows.length; i++) {
    const r = rows[i]
    const data = {
      address1: String(pick(r, mapping, 'address1') ?? '').trim(),
      city: String(pick(r, mapping, 'city') ?? '').trim(),
      state: String(pick(r, mapping, 'state') ?? '').trim(),
      postalCode: String(pick(r, mapping, 'postalCode') ?? '').trim(),
      suite: (pick(r, mapping, 'suite') ?? undefined) as any,
      rsf: toInt(pick(r, mapping, 'rsf')) ?? undefined,
      floor: (pick(r, mapping, 'floor') ?? undefined) as any,
      condition: (pick(r, mapping, 'condition') ?? undefined) as any,
      deliveryDate: toDate(pick(r, mapping, 'deliveryDate')) ?? undefined,
      askingRentPsf: toFloat(pick(r, mapping, 'askingRentPsf')) ?? undefined,
      leaseType: (pick(r, mapping, 'leaseType') ?? undefined) as any,
      opExPsf: toFloat(pick(r, mapping, 'opExPsf')) ?? undefined,
      baseYear: toInt(pick(r, mapping, 'baseYear')) ?? undefined,
      nnnPsf: toFloat(pick(r, mapping, 'nnnPsf')) ?? undefined,
      tiPsf: toFloat(pick(r, mapping, 'tiPsf')) ?? undefined,
      freeRentMonths: toInt(pick(r, mapping, 'freeRentMonths')) ?? undefined,
      escalationPct: toFloat(pick(r, mapping, 'escalationPct')) ?? undefined,
      termMin: toInt(pick(r, mapping, 'termMin')) ?? undefined,
      termMax: toInt(pick(r, mapping, 'termMax')) ?? undefined
    }
    const safe = availSchema.safeParse(data)
    if (!safe.success) { errors.push({ row: i+1, issues: safe.error.issues.map(x=>x.message) }); continue }

    const prop = await findOrCreateProperty(orgId, data)
    await prisma.availability.create({
      data: {
        propertyId: prop.id,
        suite: data.suite ?? null,
        rsf: data.rsf ?? null,
        floor: data.floor ?? null,
        condition: data.condition ?? null,
        deliveryDate: data.deliveryDate ?? null,
        askingRentPsf: data.askingRentPsf as any,
        leaseType: data.leaseType ?? null,
        opExPsf: data.opExPsf as any,
        baseYear: data.baseYear ?? null,
        nnnPsf: data.nnnPsf as any,
        tiPsf: data.tiPsf as any,
        freeRentMonths: data.freeRentMonths ?? null,
        escalationPct: data.escalationPct as any,
        termMin: data.termMin ?? null,
        termMax: data.termMax ?? null
      }
    })
    created++
  }

  return NextResponse.json({ ok: true, created, errorCount: errors.length, errors })
}

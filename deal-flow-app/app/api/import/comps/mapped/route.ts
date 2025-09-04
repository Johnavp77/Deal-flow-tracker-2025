import { NextResponse } from 'next/server'
import { z } from 'zod'
import { prisma } from '@/lib/db'
import { requestSchema, pick, toInt, toFloat, toDate, findOrCreateProperty } from '../../_helpers'
import { getDefaultOrgId } from '../../utils'

const compSchema = z.object({
  compType: z.enum(['Lease','Sale'], { message: 'compType must be Lease or Sale' }),
  address1: z.string().min(1),
  city: z.string().min(1),
  state: z.string().min(1),
  postalCode: z.string().min(1),
  rsf: z.number().int().positive().optional().nullable(),
  rentPsfStart: z.number().nonnegative().optional().nullable(),
  escalationPct: z.number().nonnegative().optional().nullable(),
  tiPsf: z.number().nonnegative().optional().nullable(),
  freeRentMonths: z.number().int().nonnegative().optional().nullable(),
  compDate: z.date().optional().nullable(),
  sourceUrl: z.string().url().optional().nullable()
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
    const compTypeRaw = String(pick(r, mapping, 'compType') ?? '').toLowerCase()
    const compType = compTypeRaw === 'sale' ? 'Sale' : 'Lease'
    const data = {
      compType,
      address1: String(pick(r, mapping, 'address1') ?? '').trim(),
      city: String(pick(r, mapping, 'city') ?? '').trim(),
      state: String(pick(r, mapping, 'state') ?? '').trim(),
      postalCode: String(pick(r, mapping, 'postalCode') ?? '').trim(),
      rsf: toInt(pick(r, mapping, 'rsf')) ?? undefined,
      rentPsfStart: toFloat(pick(r, mapping, 'rentPsfStart')) ?? undefined,
      escalationPct: toFloat(pick(r, mapping, 'escalationPct')) ?? undefined,
      tiPsf: toFloat(pick(r, mapping, 'tiPsf')) ?? undefined,
      freeRentMonths: toInt(pick(r, mapping, 'freeRentMonths')) ?? undefined,
      compDate: toDate(pick(r, mapping, 'compDate')) ?? undefined,
      sourceUrl: (pick(r, mapping, 'sourceUrl') ?? undefined) as any
    }
    const safe = compSchema.safeParse(data)
    if (!safe.success) { errors.push({ row: i+1, issues: safe.error.issues.map(x=>x.message) }); continue }

    const prop = await findOrCreateProperty(orgId, data)
    await prisma.comp.create({
      data: {
        propertyId: prop.id,
        compType: compType as any,
        rsf: data.rsf ?? null,
        rentPsfStart: data.rentPsfStart as any,
        escalationPct: data.escalationPct as any,
        tiPsf: data.tiPsf as any,
        freeRentMonths: data.freeRentMonths ?? null,
        compDate: data.compDate ?? null,
        sourceUrl: data.sourceUrl ?? null
      }
    })
    created++
  }

  return NextResponse.json({ ok: true, created, errorCount: errors.length, errors })
}

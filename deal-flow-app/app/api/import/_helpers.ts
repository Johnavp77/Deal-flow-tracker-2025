import { z } from 'zod'
import { prisma } from '@/lib/db'

export const requestSchema = z.object({
  mapping: z.record(z.string()),
  rows: z.array(z.record(z.any()))
})

export function pick(row: any, mapping: Record<string,string>, key: string) {
  const col = mapping[key]
  return col ? row[col] : undefined
}

export function toInt(v: any) { const n = parseInt(String(v??'').replace(/[,\s]/g,''),10); return Number.isFinite(n) ? n : undefined }
export function toFloat(v: any) { const n = parseFloat(String(v??'').replace(/[,\s]/g,'')); return Number.isFinite(n) ? n : undefined }
export function toDate(v: any) { const s = String(v??'').trim(); const d = s ? new Date(s) : undefined; return (d && !isNaN(d.getTime())) ? d : undefined }

export async function findOrCreateProperty(orgId: string, data: { address1?: string, city?: string, state?: string, postalCode?: string }) {
  const { address1, city, state, postalCode } = data
  let p = await prisma.property.findFirst({ where: { orgId, address1: address1 ?? null, city: city ?? null, state: state ?? null, postalCode: postalCode ?? null } })
  if (!p) {
    p = await prisma.property.create({ data: { orgId, address1: address1 ?? null, city: city ?? null, state: state ?? null, postalCode: postalCode ?? null } })
  }
  return p
}

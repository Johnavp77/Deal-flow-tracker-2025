import { prisma } from '@/lib/db'
import type { Prisma } from '@prisma/client'

export async function getDefaultOrgId(): Promise<string> {
  const org = await prisma.organization.findFirst()
  if (org) return org.id
  const created = await prisma.organization.create({ data: { name: 'Webster Realty Advisors' } })
  return created.id
}

export function toInt(v: any) { const n = parseInt(String(v||'').trim(), 10); return isNaN(n) ? null : n }
export function toFloat(v: any) { const n = parseFloat(String(v||'').trim()); return isNaN(n) ? null : n }
export function toDate(v: any) { const s = String(v||'').trim(); const d = s ? new Date(s) : null; return (d && !isNaN(d.getTime())) ? d : null }

export function normalizePropertyType(s?: string|null): Prisma.PropertyType | null {
  const x = (s||'').toLowerCase()
  if (x==='office') return 'Office'
  if (x==='industrial') return 'Industrial'
  if (x==='flex') return 'Flex'
  if (x==='lab' || x==='life science' || x==='life-science') return 'Lab'
  if (x==='medical') return 'Medical'
  if (x==='retail') return 'Retail'
  return null
}
export function normalizeBuildingClass(s?: string|null): Prisma.BuildingClass | null {
  const x = (s||'').toUpperCase()
  if (x==='A') return 'A'
  if (x==='B') return 'B'
  if (x==='C') return 'C'
  return null
}

export function propKey(addr?: string|null, city?: string|null, state?: string|null, postal?: string|null) {
  return [addr, city, state, postal].map(x => (x||'').trim().toUpperCase()).join('|')
}

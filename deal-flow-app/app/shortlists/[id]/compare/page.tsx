import { prisma } from '@/lib/db'
import CompareMatrix from '@/components/CompareMatrix'
import { Scenario } from '@/lib/finance'
import PdfButton from '@/components/PdfButton'

export default async function ComparePage({ params }: { params: { id: string } }) {
  const shortlist = await prisma.shortlist.findUnique({
    where: { id: params.id },
    include: { items: { include: { property: true, availability: true } }, deal: { include: { requirements: true, client: true } } }
  })
  if (!shortlist) return <div className="page">Shortlist not found</div>

  const items = shortlist.items.map(it => ({
    id: it.id,
    name: `${it.property.address1 ?? 'Property'}${it.availability?.suite ? ' — ' + it.availability.suite : ''}`,
    rsf: it.availability?.rsf,
    askingRentPsf: it.availability?.askingRentPsf ? Number(it.availability.askingRentPsf) : null,
    nnnPsf: it.availability?.nnnPsf ? Number(it.availability.nnnPsf) : null,
    opExPsf: it.availability?.opExPsf ? Number(it.availability.opExPsf) : null,
    leaseType: it.availability?.leaseType ?? undefined,
    deliveryDate: it.availability?.deliveryDate ? it.availability.deliveryDate.toISOString() : null,
    city: it.property.city,
    submarket: it.property.submarket
  }))

  const defaultScenario: Scenario = {
    rsf: shortlist.deal.requirements?.rsfMax || items[0]?.rsf || 10000,
    termMonths: shortlist.deal.requirements?.termMonths || 84,
    startRentPsf: items[0]?.askingRentPsf || 38,
    escalationPct: 3,
    freeRentMonths: 3,
    tiPsf: 40,
    discountRatePct: 7,
    leaseType: (items[0]?.leaseType as any) || 'NNN',
    nnnPsf: items[0]?.nnnPsf || 12,
    opExPsf: items[0]?.opExPsf || 0,
    baseYearOpExPsf: 0,
    currentOpExPsf: 0
  }

  return (
    <div className="page">
      <div className="flex items-center justify-between"><h1>Compare — {shortlist.deal.title}</h1><PdfButton path={`/shortlists/${shortlist.id}/compare/print`} filename={`compare_${shortlist.id}.pdf`} /></div>
      <CompareMatrix items={items} defaultScenario={defaultScenario} />
    </div>
  )
}

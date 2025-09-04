import { prisma } from '@/lib/db'
import { effectiveRentPsfYr, monthlyFromAnnual, buildMonthlyBaseRentSchedule, addOpsToSchedule } from '@/lib/finance'

export default async function ComparePrint({ params }: { params: { id: string } }) {
  const shortlist = await prisma.shortlist.findUnique({
    where: { id: params.id },
    include: { items: { include: { property: true, availability: true } }, deal: { include: { client: true, requirements: true } } }
  })
  if (!shortlist) return <div className="page">Shortlist not found</div>
  const items = shortlist.items.map(it => ({
    id: it.id,
    name: `${it.property.address1 ?? 'Property'}${it.availability?.suite ? ' — ' + it.availability.suite : ''}`,
    rsf: it.availability?.rsf ?? undefined,
    askingRentPsf: Number(it.availability?.askingRentPsf ?? 0) || 0,
    nnnPsf: Number(it.availability?.nnnPsf ?? 0) || 0,
    opExPsf: Number(it.availability?.opExPsf ?? 0) || 0,
    leaseType: it.availability?.leaseType ?? 'NNN',
    city: it.property.city ?? '',
    submarket: it.property.submarket ?? ''
  }))

  const scenario = {
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

  const data = items.map(it => {
    const s = { ...scenario, leaseType: (it.leaseType as any) || scenario.leaseType, nnnPsf: it.nnnPsf || scenario.nnnPsf, opExPsf: it.opExPsf || scenario.opExPsf }
    const er = effectiveRentPsfYr(s as any)
    return { ...it, er }
  })

  const min = Math.min(...data.map(d => d.er))
  const max = Math.max(...data.map(d => d.er))
  const color = (er: number) => {
    if (!isFinite(min) || !isFinite(max) || max === min) return 'bg-slate-100'
    const t = (er - min) / (max - min)
    if (t < 0.33) return 'bg-green-100'
    if (t < 0.66) return 'bg-yellow-100'
    return 'bg-red-100'
  }

  return (
    <div className="page print:!p-0">
      <header className="flex items-center gap-4 mb-4 print:mb-0">
        <img src="/branding/wra-logo.svg" alt="WRA" className="h-12" />
        <div>
          <div className="text-sm text-slate-500">Compare Matrix</div>
          <div className="text-lg font-semibold">{shortlist.deal.client?.name} — {shortlist.deal.title}</div>
        </div>
      </header>

      <section className="card print:shadow-none print:border-0 print:rounded-none">
        <h2>Scenario</h2>
        <div className="grid md:grid-cols-3 gap-2 text-sm">
          <div>RSF: <b>{scenario.rsf}</b></div>
          <div>Term: <b>{scenario.termMonths} mo</b></div>
          <div>Start Rent: <b>${scenario.startRentPsf}/RSF/Yr</b></div>
          <div>Escalation: <b>{scenario.escalationPct}%</b></div>
          <div>Free Rent: <b>{scenario.freeRentMonths} mo</b></div>
          <div>TI: <b>${scenario.tiPsf}/RSF</b></div>
          <div>Discount: <b>{scenario.discountRatePct}%</b></div>
          <div>Lease Type: <b>{scenario.leaseType}</b></div>
          <div>Ops: <b>{scenario.leaseType==='NNN' ? `$${scenario.nnnPsf}/RSF/Yr` : scenario.leaseType==='BaseYear' ? `Base ${scenario.baseYearOpExPsf} → Current ${scenario.currentOpExPsf}` : '-'}</b></div>
        </div>
      </section>

      <section className="mt-4 card print:shadow-none print:border-0 print:rounded-none">
        <div className="overflow-x-auto">
          <table className="min-w-[900px] w-full text-sm">
            <thead>
              <tr>
                <th className="text-left p-2 w-60">Field</th>
                {data.map((it) => (
                  <th key={it.id} className="text-left p-2 w-64">
                    <div className="font-medium">{it.name}</div>
                    <div className="text-xs text-slate-500">{it.city} • {it.submarket}</div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              <Tr label="RSF">{data.map(it => <Td key={it.id}>{it.rsf || '-'}</Td>)}</Tr>
              <Tr label="Asking Rent ($/RSF/Yr)">{data.map(it => <Td key={it.id}>{it.askingRentPsf?.toFixed(2)}</Td>)}</Tr>
              <Tr label="NNN or OpEx ($/RSF/Yr)">
                {data.map(it => <Td key={it.id}>{it.nnnPsf ? `${it.nnnPsf.toFixed(2)} (NNN)` : (it.opExPsf ? `${it.opExPsf.toFixed(2)} (OpEx)` : '-')}</Td>)}
              </Tr>
              <Tr label="Effective Rent ($/RSF/Yr)">
                {data.map(it => <Td key={it.id}><span className={`px-2 py-1 rounded ${color(it.er)}`}>{it.er.toFixed(2)}</span></Td>)}
              </Tr>
            </tbody>
          </table>
        </div>
      </section>

      <style jsx global>{`
        @media print {
          .card { box-shadow: none !important; border: none !important; border-radius: 0 !important; }
          header { margin-top: 8mm; }
          section { page-break-inside: avoid; }
        }
      `}</style>
    </div>
  )
}

function Tr({ label, children }: { label: string, children: any }) {
  return (<tr className="border-t"><td className="p-2 font-medium">{label}</td>{children}</tr>)
}
function Td({ children }: { children: any }) { return <td className="p-2 align-top">{children}</td> }

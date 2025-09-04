'use client'
import { useMemo, useState } from 'react'
import { Scenario, effectiveRentPsfYr } from '@/lib/finance'

type Item = {
  id: string
  name: string
  rsf?: number | null
  askingRentPsf?: number | null
  nnnPsf?: number | null
  opExPsf?: number | null
  leaseType?: string | null
  deliveryDate?: string | null
  city?: string | null
  submarket?: string | null
}

type Props = { items: Item[]; defaultScenario: Scenario }

export default function CompareMatrix({ items, defaultScenario }: Props) {
  const [scenario, setScenario] = useState<Scenario>(defaultScenario)
  const rows = useMemo(() => {
    const data = items.map((it) => {
      const s: Scenario = {
        ...scenario,
        rsf: scenario.rsf || (it.rsf || 0),
        leaseType: (it.leaseType as any) || scenario.leaseType,
        nnnPsf: it.nnnPsf ?? scenario.nnnPsf,
        opExPsf: it.opExPsf ?? scenario.opExPsf
      }
      const er = effectiveRentPsfYr(s)
      return { ...it, er }
    })
    const ers = data.map(d => d.er)
    const min = Math.min(...ers)
    const max = Math.max(...ers)
    const color = (er: number) => {
      if (!isFinite(min) || !isFinite(max) || max === min) return 'bg-slate-100'
      const t = (er - min) / (max - min)
      if (t < 0.33) return 'bg-green-100'
      if (t < 0.66) return 'bg-yellow-100'
      return 'bg-red-100'
    }
    return { data, color }
  }, [items, scenario])

  return (
    <div className="space-y-6">
      <ScenarioBar scenario={scenario} onChange={setScenario} />
      <div className="overflow-x-auto">
        <table className="min-w-[900px] w-full text-sm">
          <thead>
            <tr className="sticky top-0 bg-white">
              <th className="text-left p-2 w-60">Field</th>
              {rows.data.map((it) => (
                <th key={it.id} className="text-left p-2 w-64">
                  <div className="font-medium">{it.name}</div>
                  <div className="text-xs text-slate-500">{it.city} • {it.submarket}</div>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            <Tr label="RSF">{rows.data.map(it => <Td key={it.id}>{it.rsf?.toLocaleString() || '-'}</Td>)}</Tr>
            <Tr label="Asking Rent ($/RSF/Yr)">{rows.data.map(it => <Td key={it.id}>{it.askingRentPsf?.toFixed(2) || '-'}</Td>)}</Tr>
            <Tr label="NNN or OpEx ($/RSF/Yr)">
              {rows.data.map(it => <Td key={it.id}>
                {it.nnnPsf != null ? `${it.nnnPsf.toFixed(2)} (NNN)` : (it.opExPsf != null ? `${it.opExPsf.toFixed(2)} (OpEx)` : '-')}
              </Td>)}
            </Tr>
            <Tr label="Delivery">
              {rows.data.map(it => <Td key={it.id}>{it.deliveryDate ? new Date(it.deliveryDate).toLocaleDateString() : '-'}</Td>)}
            </Tr>
            <Tr label="Effective Rent ($/RSF/Yr)">
              {rows.data.map(it => (
                <Td key={it.id}><span className={`px-2 py-1 rounded ${rows.color(it.er)}`}>{it.er.toFixed(2)}</span></Td>
              ))}
            </Tr>
          </tbody>
        </table>
      </div>
      <div className="text-xs text-slate-500">Note: ER includes escalations, free rent, TI, and ops per scenario. Use the browser print dialog for a PDF.</div>
    </div>
  )
}

function Tr({ label, children }: { label: string, children: any }) {
  return (<tr className="border-t"><td className="p-2 font-medium sticky left-0 bg-white">{label}</td>{children}</tr>)
}
function Td({ children }: { children: any }) { return <td className="p-2 align-top">{children}</td> }

function ScenarioBar({ scenario, onChange }: { scenario: any, onChange: (s: any) => void }) {
  const set = (k: string, v: any) => onChange({ ...scenario, [k]: v })
  return (
    <div className="card">
      <div className="flex flex-wrap gap-4 items-end">
        <Num label="RSF" value={scenario.rsf} onChange={(v)=>set('rsf', v)} />
        <Num label="Term (mo)" value={scenario.termMonths} onChange={(v)=>set('termMonths', v)} />
        <Num label="Start Rent ($/RSF/Yr)" value={scenario.startRentPsf} onChange={(v)=>set('startRentPsf', v)} />
        <Num label="Escalation (%)" value={scenario.escalationPct} onChange={(v)=>set('escalationPct', v)} />
        <Num label="Free Rent (mo)" value={scenario.freeRentMonths} onChange={(v)=>set('freeRentMonths', v)} />
        <Num label="TI ($/RSF)" value={scenario.tiPsf} onChange={(v)=>set('tiPsf', v)} />
        <Num label="Discount (%)" value={scenario.discountRatePct} onChange={(v)=>set('discountRatePct', v)} />
        <select className="border rounded p-2" value={scenario.leaseType} onChange={(e)=>onChange({ ...scenario, leaseType: e.target.value })}>
          <option>NNN</option><option>Gross</option><option>BaseYear</option><option>Modified Gross</option>
        </select>
        <Num label="NNN ($/RSF/Yr)" value={scenario.nnnPsf ?? 0} onChange={(v)=>set('nnnPsf', v)} />
        <Num label="OpEx ($/RSF/Yr)" value={scenario.opExPsf ?? 0} onChange={(v)=>set('opExPsf', v)} />
        <Num label="Base Yr OpEx" value={scenario.baseYearOpExPsf ?? 0} onChange={(v)=>set('baseYearOpExPsf', v)} />
        <Num label="Current OpEx" value={scenario.currentOpExPsf ?? 0} onChange={(v)=>set('currentOpExPsf', v)} />
      </div>
    </div>
  )
}
function Num({ label, value, onChange }: { label: string, value: number, onChange: (v:number)=>void }) {
  return (<label className="text-sm"><div className="mb-1">{label}</div><input type="number" step="0.01" className="border rounded p-2 w-36" value={value ?? 0} onChange={(e)=>onChange(parseFloat(e.target.value))} /></label>)
}

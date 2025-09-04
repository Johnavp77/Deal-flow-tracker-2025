'use client'
import { useMemo, useState } from 'react'
import { LOITemplate } from '@/lib/loiTemplates'
import { mergeTemplate, LOIValues } from '@/lib/loi'

type Props = { template: LOITemplate; defaults: LOIValues; onSave: (vals: LOIValues, merged: string) => Promise<void> }
export default function LOIForm({ template, defaults, onSave }: Props) {
  const [vals, setVals] = useState<LOIValues>(defaults)
  const merged = useMemo(() => mergeTemplate(template, vals), [template, vals])
  const set = (k: string, v: any) => setVals({ ...vals, [k]: v })
  return (
    <div className="grid md:grid-cols-2 gap-6">
      <div className="card space-y-3">
        <h2>Terms</h2>
        <Field label="Client Name" k="CLIENT_NAME" vals={vals} set={set} />
        <Field label="Property Address" k="PROPERTY_ADDRESS" vals={vals} set={set} />
        <Field label="RSF" k="RSF" vals={vals} set={set} type="number" />
        <Field label="Term (months)" k="TERM_MONTHS" vals={vals} set={set} type="number" />
        <Field label="Commencement Target" k="COMMENCEMENT_TARGET" vals={vals} set={set} />
        <Field label="Start Rent ($/RSF/Yr)" k="START_RENT_PSF" vals={vals} set={set} type="number" />
        <Field label="Escalation (%)" k="ESCALATION_PCT" vals={vals} set={set} type="number" />
        <Field label="Ops Structure" k="OPS_STRUCTURE" vals={vals} set={set} placeholder="NNN @ $12.00/RSF/Yr" />
        <Field label="TI ($/RSF)" k="TI_PSF" vals={vals} set={set} type="number" />
        <Field label="Free Rent (months)" k="FREE_RENT_MONTHS" vals={vals} set={set} type="number" />
        <Field label="Security Deposit" k="SECURITY_DEPOSIT_DESC" vals={vals} set={set} placeholder="Equal to 3 months' gross rent" />
        <Field label="Parking" k="PARKING_DESC" vals={vals} set={set} placeholder="3.0/1,000 RSF; unreserved" />
        <Field label="Rights" k="RIGHTS_DESC" vals={vals} set={set} placeholder="One 5-year renewal at FMV; ROFR on Adjacent Suite" />
        <Field label="Landlord Contact" k="LANDLORD_CONTACT" vals={vals} set={set} />
        <Field label="Landlord Name" k="LANDLORD_NAME" vals={vals} set={set} />
        <Field label="Tenant Signatory Name" k="TENANT_SIGNATORY_NAME" vals={vals} set={set} />
        <Field label="Tenant Signatory Title" k="TENANT_SIGNATORY_TITLE" vals={vals} set={set} />
        <button className="mt-2 px-4 py-2 rounded bg-wraBlue text-white" onClick={async () => { await onSave(vals, merged) }}>Save Draft</button>
      </div>
      <div className="card">
        <h2>Preview</h2>
        <div className="whitespace-pre-wrap leading-6 text-[13px]">{merged}</div>
        <div className="mt-3 text-xs text-slate-500">Tip: Use the browser’s Print dialog to save as PDF.</div>
      </div>
    </div>
  )
}
function Field({ label, k, vals, set, type='text', placeholder='' }:
  { label: string, k: string, vals: any, set: (k:string,v:any)=>void, type?: string, placeholder?: string }) {
  return (
    <label className="block text-sm">
      <div className="mb-1">{label}</div>
      <input type={type} placeholder={placeholder} className="border rounded p-2 w-full"
        value={vals[k] ?? ''} onChange={(e)=> set(k, type==='number' ? Number(e.target.value) : e.target.value)} />
    </label>
  )
}

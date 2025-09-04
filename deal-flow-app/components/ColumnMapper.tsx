'use client'

import Papa from 'papaparse'
import { useMemo, useState } from 'react'

export type TargetField = { key: string; label: string; required?: boolean; note?: string }

type Props = {
  targetFields: TargetField[]
  endpoint: string                 // API endpoint to POST {rows, mapping}
  templateHref: string             // link to CSV template
  title: string
}

export default function ColumnMapper({ targetFields, endpoint, templateHref, title }: Props) {
  const [file, setFile] = useState<File | null>(null)
  const [rows, setRows] = useState<any[]>([])
  const [cols, setCols] = useState<string[]>([])
  const [mapping, setMapping] = useState<Record<string, string>>({})
  const [msg, setMsg] = useState<string>('')
  const [busy, setBusy] = useState(false)
  const [result, setResult] = useState<any>(null)

  function autoMap(headers: string[]) {
    const map: Record<string, string> = {}
    const norm = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/g, '')
    for (const t of targetFields) {
      const candidates = headers.filter(h => norm(h) === norm(t.key) || norm(h) === norm(t.label))
      if (candidates[0]) map[t.key] = candidates[0]
    }
    setMapping(map)
  }

  async function parseFile(f: File) {
    setMsg('')
    const text = await f.text()
    const parsed = Papa.parse(text, { header: true, skipEmptyLines: true })
    if (parsed.errors?.length) {
      setMsg('Parse error: ' + parsed.errors[0].message)
      return
    }
    const r = parsed.data as any[]
    const headers = parsed.meta.fields || Object.keys(r[0] || {})
    setRows(r)
    setCols(headers || [])
    autoMap(headers || [])
  }

  async function submit() {
    setBusy(true); setMsg('')
    try {
      // basic required mapping check
      const missing = targetFields.filter(t => t.required && !mapping[t.key])
      if (missing.length) { setMsg('Missing required mappings: ' + missing.map(m => m.label).join(', ')); setBusy(false); return }
      const res = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ rows, mapping }) })
      const j = await res.json()
      if (!res.ok) setMsg('Error: ' + (j.error || 'Import failed'))
      else { setResult(j); setMsg(JSON.stringify(j, null, 2)) }
    } catch (e: any) {
      setMsg('Error: ' + e.message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="page">
      <h1>{title} — Column Mapping Importer</h1>
      <div className="card space-y-3 max-w-4xl">
        <label className="text-sm">
          <div className="mb-1">CSV File</div>
          <input type="file" accept=".csv,text/csv" onChange={(e)=>{ const f=e.target.files?.[0]||null; setFile(f); if (f) parseFile(f) }} />
        </label>
        <div className="text-xs text-slate-500">Need a starting point? <a href={templateHref} className="underline" download>Download template</a>.</div>
      </div>

      {cols.length > 0 && (
        <div className="card mt-4">
          <h2 className="mb-3">Map your columns</h2>
          <div className="grid md:grid-cols-2 gap-3">
            {targetFields.map(tf => (
              <label key={tf.key} className="text-sm">
                <div className="mb-1">
                  {tf.label}{tf.required ? ' *' : ''}
                  {tf.note ? <span className="text-xs text-slate-500"> — {tf.note}</span> : null}
                </div>
                <select className="border rounded p-2 w-full" value={mapping[tf.key] || ''} onChange={(e)=>setMapping({...mapping, [tf.key]: e.target.value})}>
                  <option value="">-- Select column --</option>
                  {cols.map(c => <option key={c} value={c}>{c}</option>)}
                </select>
              </label>
            ))}
          </div>
          <div className="mt-4">
            <button disabled={busy || !file} className="px-4 py-2 rounded bg-wraBlue text-white" onClick={submit}>
              {busy ? 'Validating & Importing…' : 'Validate & Import'}
            </button>
          </div>
        </div>
      )}

      {rows.length > 0 && (
        <div className="card mt-4">
          <h2>Preview (first 5 rows)</h2>
          <div className="overflow-auto text-xs">
            <table className="min-w-[800px] w-full">
              <thead><tr>{cols.map(c => <th key={c} className="text-left p-2 border-b">{c}</th>)}</tr></thead>
              <tbody>
                {rows.slice(0,5).map((r,i)=>(
                  <tr key={i}>{cols.map(c => <td key={c} className="p-2 border-b">{String(r[c] ?? '')}</td>)}</tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {result?.errors?.length ? (
  <div className="card mt-4">
    <h2 className="mb-2">Errors</h2>
    <div className="text-sm mb-2">Total: {result.errors.length}</div>
    <div className="flex gap-2 mb-3">
      <button
        className="px-3 py-1 rounded bg-slate-700 text-white text-xs"
        onClick={() => {
          const rows = result.errors.map((e: any) => ({ row: e.row, issues: (e.issues||[]).join('; ') }))
          const csv = Papa.unparse(rows)
          const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
          const url = URL.createObjectURL(blob)
          const a = document.createElement('a')
          a.href = url
          a.download = `${title.replace(/\s+/g,'_').toLowerCase()}_import_errors.csv`
          a.click()
          URL.revokeObjectURL(url)
        }}
      >Download Error CSV</button>
    </div>
    <div className="overflow-auto text-xs">
      <table className="min-w-[600px] w-full">
        <thead><tr><th className="text-left p-2 border-b w-24">Row</th><th className="text-left p-2 border-b">Issues</th></tr></thead>
        <tbody>
          {result.errors.slice(0,50).map((e: any, i: number) => (
            <tr key={i}><td className="p-2 border-b">{e.row}</td><td className="p-2 border-b">{(e.issues||[]).join('; ')}</td></tr>
          ))}
        </tbody>
      </table>
      {result.errors.length > 50 && <div className="mt-2 text-xs text-slate-500">Showing first 50… Download CSV for full list.</div>}
    </div>
  </div>
) : null}

      {msg && <pre className="mt-4 text-xs whitespace-pre-wrap">{msg}</pre>}
    </div>
  )
}

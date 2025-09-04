'use client'
import { useState } from 'react'

export default function OptimizeButton({ tourId }: { tourId: string }) {
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState<string>('')
  async function run() {
    setBusy(true); setMsg('')
    const res = await fetch(`/api/tours/${tourId}/optimize`, { method: 'POST' })
    const j = await res.json()
    if (!res.ok) setMsg('Error: ' + (j.error || 'Failed'))
    else { setMsg('Optimized route. New order: ' + j.order.join(', ')); location.reload() }
    setBusy(false)
  }
  return (
    <div className="flex flex-col items-end gap-1">
      <button onClick={run} disabled={busy} className="px-4 py-2 rounded bg-slate-700 text-white">{busy ? 'Optimizing…' : 'Optimize Route'}</button>
      {msg && <div className="text-xs text-slate-500">{msg}</div>}
    </div>
  )
}

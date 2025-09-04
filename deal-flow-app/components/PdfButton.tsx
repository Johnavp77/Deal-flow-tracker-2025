'use client'
import { useState } from 'react'

export default function PdfButton({ path, filename = 'export.pdf' }: { path: string, filename?: string }) {
  const [busy, setBusy] = useState(false)
  async function run() {
    setBusy(true)
    try {
      const res = await fetch('/api/export/pdf', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ path, filename })
      })
      if (!res.ok) {
        const j = await res.json().catch(()=>({error:'Failed'}))
        alert('PDF export failed: ' + (j.error || res.statusText))
      } else {
        const blob = await res.blob()
        const url = URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = filename
        a.click()
        URL.revokeObjectURL(url)
      }
    } finally {
      setBusy(false)
    }
  }
  return <button onClick={run} disabled={busy} className="px-4 py-2 rounded bg-wraBlue text-white">{busy ? 'Exporting…' : 'Export PDF'}</button>
}

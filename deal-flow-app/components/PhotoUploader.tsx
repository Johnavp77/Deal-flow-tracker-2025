'use client'
import { useState } from 'react'

export default function PhotoUploader({ propertyId }: { propertyId: string }) {
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState<string>('')

  async function onChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setBusy(true); setMsg('')
    const fd = new FormData()
    fd.append('file', file)
    const res = await fetch(`/api/properties/${propertyId}/photos`, { method: 'POST', body: fd })
    const j = await res.json()
    if (!res.ok) setMsg('Error: ' + (j.error || 'Upload failed'))
    else { setMsg('Uploaded'); location.reload() }
    setBusy(false)
  }

  return (
    <label className="inline-block">
      <span className="px-3 py-2 rounded bg-slate-700 text-white text-sm cursor-pointer">{busy ? 'Uploading…' : 'Upload Photo'}</span>
      <input type="file" accept="image/*" className="hidden" onChange={onChange} />
    </label>
  )
}

'use client'

export default function MapInset({ lat, lng, zoom=15, width=800, height=400 }: { lat?: number|null, lng?: number|null, zoom?: number, width?: number, height?: number }) {
  const token = process.env.NEXT_PUBLIC_MAPBOX_TOKEN
  if (!lat || !lng) return <div className="text-xs text-slate-500">No coordinates</div>
  if (!token) return <div className="text-xs text-slate-500">Set NEXT_PUBLIC_MAPBOX_TOKEN to render map.</div>
  const src = `https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/pin-s+004B8D(${lng},${lat})/${lng},${lat},${zoom}/${width}x${height}@2x?access_token=${token}`
  return <img src={src} alt="Map inset" className="w-full rounded-lg border" />
}

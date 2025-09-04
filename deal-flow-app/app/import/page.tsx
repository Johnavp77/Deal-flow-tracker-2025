import Link from 'next/link'

export default function ImportIndex() {
  return (
    <div className="page">
      <h1>CSV Importers</h1>
      <div className="grid md:grid-cols-3 gap-4">
        <Card title="Properties" href="/import/properties" template="/csv-templates/properties.csv" />
        <Card title="Availabilities" href="/import/availabilities" template="/csv-templates/availabilities.csv" />
        <Card title="Comps" href="/import/comps" template="/csv-templates/comps.csv" />
      </div>
    </div>
  )
}
function Card({ title, href, template }: { title: string, href: string, template: string }) {
  return (
    <div className="card">
      <div className="font-medium">{title} Importer</div>
      <div className="text-sm text-slate-500 mb-3">Upload a CSV matching the template headers.</div>
      <div className="flex gap-3">
        <Link href={href} className="underline">Open</Link>
        <a className="underline" href={template} download>Download Template</a>
      </div>
    </div>
  )
}

import ColumnMapper from '@/components/ColumnMapper'

export default function ImportComps() {
  return (
    <ColumnMapper
      title="Comps"
      endpoint="/api/import/comps/mapped"
      templateHref="/csv-templates/comps.csv"
      targetFields={[
        { key: 'compType', label: 'Comp Type', required: true, note: 'Lease or Sale' },
        { key: 'address1', label: 'Address 1', required: true },
        { key: 'city', label: 'City', required: true },
        { key: 'state', label: 'State', required: true },
        { key: 'postalCode', label: 'Postal Code', required: true },
        { key: 'rsf', label: 'RSF' },
        { key: 'rentPsfStart', label: 'Start Rent $/RSF/Yr' },
        { key: 'escalationPct', label: 'Escalation %' },
        { key: 'tiPsf', label: 'TI $/RSF' },
        { key: 'freeRentMonths', label: 'Free Rent Months' },
        { key: 'compDate', label: 'Comp Date' },
        { key: 'sourceUrl', label: 'Source URL' }
      ]}
    />
  )
}

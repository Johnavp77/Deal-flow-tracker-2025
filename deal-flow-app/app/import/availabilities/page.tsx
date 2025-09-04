import ColumnMapper from '@/components/ColumnMapper'

export default function ImportAvailabilities() {
  return (
    <ColumnMapper
      title="Availabilities"
      endpoint="/api/import/availabilities/mapped"
      templateHref="/csv-templates/availabilities.csv"
      targetFields={[
        { key: 'address1', label: 'Address 1', required: true },
        { key: 'city', label: 'City', required: true },
        { key: 'state', label: 'State', required: true },
        { key: 'postalCode', label: 'Postal Code', required: true },
        { key: 'suite', label: 'Suite' },
        { key: 'rsf', label: 'RSF' },
        { key: 'floor', label: 'Floor' },
        { key: 'condition', label: 'Condition' },
        { key: 'deliveryDate', label: 'Delivery Date' },
        { key: 'askingRentPsf', label: 'Asking Rent $/RSF/Yr' },
        { key: 'leaseType', label: 'Lease Type' },
        { key: 'opExPsf', label: 'OpEx $/RSF/Yr' },
        { key: 'baseYear', label: 'Base Year' },
        { key: 'nnnPsf', label: 'NNN $/RSF/Yr' },
        { key: 'tiPsf', label: 'TI $/RSF' },
        { key: 'freeRentMonths', label: 'Free Rent Months' },
        { key: 'escalationPct', label: 'Escalation %' },
        { key: 'termMin', label: 'Term Min (mo)' },
        { key: 'termMax', label: 'Term Max (mo)' }
      ]}
    />
  )
}

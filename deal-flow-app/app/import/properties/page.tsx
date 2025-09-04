import ColumnMapper from '@/components/ColumnMapper'

export default function ImportProperties() {
  return (
    <ColumnMapper
      title="Properties"
      endpoint="/api/import/properties/mapped"
      templateHref="/csv-templates/properties.csv"
      targetFields={[
        { key: 'address1', label: 'Address 1', required: true },
        { key: 'city', label: 'City', required: true },
        { key: 'state', label: 'State', required: true },
        { key: 'postalCode', label: 'Postal Code', required: true },
        { key: 'submarket', label: 'Submarket' },
        { key: 'propertyType', label: 'Property Type', note: 'Office/Industrial/Flex/Lab/Medical/Retail' },
        { key: 'buildingClass', label: 'Building Class', note: 'A/B/C' },
        { key: 'rsfTotal', label: 'Building RSF' },
        { key: 'ownerName', label: 'Owner Name' },
        { key: 'sourceUrl', label: 'Source URL' },
        { key: 'lat', label: 'Latitude' },
        { key: 'lng', label: 'Longitude' }
      ]}
    />
  )
}

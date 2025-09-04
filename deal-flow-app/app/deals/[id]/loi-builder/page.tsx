import { prisma } from '@/lib/db'
import { templates } from '@/lib/loiTemplates'
import LOIForm from '@/components/LOIForm'

export default async function LOIBuilderPage({ params }: { params: { id: string } }) {
  const deal = await prisma.deal.findUnique({ where: { id: params.id }, include: { client: true, owner: true, requirements: true } })
  if (!deal) return <div className="page">Deal not found</div>
  const template = templates[0]

  async function saveDraft(values: Record<string, any>, merged: string) {
    'use server'
    const loi = await prisma.lOI.create({
      data: {
        dealId: deal.id,
        status: 'Draft',
        terms: { create: Object.entries(values).map(([k, v]) => ({ fieldName: k, value: String(v ?? '') })) }
      }
    })
    await prisma.document.create({ data: { entityType: 'LOI', entityId: loi.id, fileUrl: '', kind: 'LOI-Preview', uploadedBy: deal.ownerId } })
  }

  const defaults = {
    DATE: new Date().toLocaleDateString(),
    CLIENT_NAME: deal.client?.name ?? '',
    PROPERTY_ADDRESS: '',
    RSF: deal.requirements?.rsfMax ?? 10000,
    TERM_MONTHS: deal.requirements?.termMonths ?? 84,
    COMMENCEMENT_TARGET: '',
    START_RENT_PSF: 38,
    ESCALATION_PCT: 3,
    OPS_STRUCTURE: 'NNN @ $12.00/RSF/Yr',
    TI_PSF: 40,
    FREE_RENT_MONTHS: 3,
    SECURITY_DEPOSIT_DESC: "Equal to 3 months' gross rent",
    PARKING_DESC: '3.0/1,000 RSF; unreserved',
    RIGHTS_DESC: 'One 5-year renewal at FMV',
    LANDLORD_CONTACT: '',
    LANDLORD_NAME: '',
    TENANT_SIGNATORY_NAME: 'Authorized Signatory',
    TENANT_SIGNATORY_TITLE: 'Title'
  }

  return (
    <div className="page">
      <h1>LOI Builder — {deal.title}</h1>
      <LOIForm template={template} defaults={defaults} onSave={saveDraft} />
    </div>
  )
}

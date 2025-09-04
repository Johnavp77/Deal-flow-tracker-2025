export type LOITemplate = { key: string; name: string; body: string }

export const officeTemplate: LOITemplate = {
  key: 'office',
  name: 'Office — Standard',
  body: `[DATE]

Landlord Name
Landlord Address

Re: Letter of Intent — {{CLIENT_NAME}} at {{PROPERTY_ADDRESS}} (approx. {{RSF}} RSF)

Dear {{LANDLORD_CONTACT}},

On behalf of {{CLIENT_NAME}} ("Tenant"), this non-binding Letter of Intent ("LOI") outlines the principal terms for leasing premises at {{PROPERTY_ADDRESS}}.

1. **Premises**: Approx. {{RSF}} rentable square feet ("RSF").
2. **Term**: {{TERM_MONTHS}} months.
3. **Commencement**: The later of substantial completion of Landlord Work and delivery of premises, target {{COMMENCEMENT_TARGET}}.
4. **Base Rent**: Starting at ${{START_RENT_PSF}}/RSF/Year, with {{ESCALATION_PCT}}% annual escalations.
5. **Operating Expenses**: {{OPS_STRUCTURE}}.
6. **Tenant Improvements**: Landlord to provide TI allowance of ${{TI_PSF}}/RSF.
7. **Free Rent**: {{FREE_RENT_MONTHS}} months abated base rent commencing at Lease Commencement.
8. **Security Deposit**: {{SECURITY_DEPOSIT_DESC}}.
9. **Parking**: {{PARKING_DESC}}.
10. **Signage**: Building-standard signage per code; prominent directory listing.
11. **Rights**: {{RIGHTS_DESC}} (renewal/expansion/termination as applicable).
12. **Assignment/Subletting**: Standard with customary carve-outs for affiliates and corporate transactions.
13. **Work Letter**: Landlord to deliver premises in condition suitable for Tenant’s intended use; detailed scope to be attached to lease.
14. **Brokerage**: Landlord to recognize and compensate Webster Realty Advisors as Tenant’s exclusive representative.
15. **Confidentiality**: Both parties agree to keep terms confidential except as required.
16. **Non-Binding**: This LOI is for discussion only and is not a lease nor an agreement to lease.

If the above is acceptable, please acknowledge below and we will proceed to a lease draft.

Sincerely,

____________________________________
{{TENANT_SIGNATORY_NAME}}, {{TENANT_SIGNATORY_TITLE}}
for {{CLIENT_NAME}}

Acknowledged and Agreed:

____________________________________
{{LANDLORD_NAME}}`
}

export const templates = [officeTemplate]

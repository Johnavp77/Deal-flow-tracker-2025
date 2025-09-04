export type LeaseType = 'NNN' | 'Gross' | 'BaseYear' | 'Modified Gross'

export type Scenario = {
  rsf: number
  termMonths: number
  startRentPsf: number
  escalationPct: number
  freeRentMonths: number
  tiPsf: number
  discountRatePct: number
  leaseType: LeaseType
  nnnPsf?: number
  opExPsf?: number
  baseYearOpExPsf?: number
  currentOpExPsf?: number
}

export function monthlyFromAnnual(annual: number) { return annual / 12 }

export function buildMonthlyBaseRentSchedule(s: Scenario): number[] {
  const months = s.termMonths
  const schedule: number[] = new Array(months).fill(0)
  let currentAnnual = s.startRentPsf
  for (let m = 0; m < months; m++) {
    if (m > 0 && m % 12 === 0) currentAnnual = currentAnnual * (1 + s.escalationPct / 100)
    const baseMonthly = monthlyFromAnnual(currentAnnual)
    schedule[m] = m < s.freeRentMonths ? 0 : baseMonthly
  }
  return schedule
}
export function addOpsToSchedule(s: Scenario, base: number[]): number[] {
  const moOps =
    s.leaseType === 'NNN'
      ? monthlyFromAnnual(s.nnnPsf ?? 0)
      : s.leaseType === 'BaseYear'
        ? monthlyFromAnnual(Math.max((s.currentOpExPsf ?? 0) - (s.baseYearOpExPsf ?? 0), 0))
        : 0
  return base.map((m) => m + moOps)
}
export function npv(cashflows: number[], annualDiscountRatePct: number): number {
  const r = annualDiscountRatePct / 100 / 12
  return cashflows.reduce((acc, cf, i) => acc + cf / Math.pow(1 + r, i + 1), 0)
}
export function effectiveRentPsfYr(s: Scenario): number {
  const base = buildMonthlyBaseRentSchedule(s)
  const allIn = addOpsToSchedule(s, base)
  const tiCreditPerMonth = monthlyFromAnnual(s.tiPsf)
  const netMonthly = allIn.map((m) => m - tiCreditPerMonth)
  const npvPerRsf = npv(netMonthly, s.discountRatePct)
  return (npvPerRsf) / (s.termMonths / 12)
}

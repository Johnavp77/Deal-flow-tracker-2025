import { PrismaClient, Role, Stage } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  const org = await prisma.organization.create({ data: { name: 'Webster Realty Advisors' } });
  const john = await prisma.user.create({
    data: { orgId: org.id, fullName: 'John Webster', email: 'john@example.com', role: Role.manager }
  });
  const client = await prisma.client.create({
    data: { orgId: org.id, name: 'Clarify Health (Sample)', sector: 'Healthcare', headcount: 120, hqCity: 'Boston, MA' }
  });
  const deal = await prisma.deal.create({
    data: { orgId: org.id, clientId: client.id, ownerId: john.id, title: 'HQ Relocation 10–15k RSF', stage: Stage.discovery, probability: new prisma.Prisma.Decimal(0.25) }
  });
  await prisma.dealRequirements.create({
    data: { dealId: deal.id, rsfMin: 10000, rsfMax: 15000, termMonths: 84, leaseType: 'NNN', submarkets: ['Burlington', 'Woburn'], budgetPsf: new prisma.Prisma.Decimal(38) }
  });

  // Sample properties and availabilities
  const prop1 = await prisma.property.create({
    data: { orgId: org.id, address1: '10 Corporate Dr', city: 'Burlington', state: 'MA', postalCode: '01803', submarket: 'Burlington/Woburn', propertyType: 'Office', rsfTotal: 120000, lat: new prisma.Prisma.Decimal(42.4848), lng: new prisma.Prisma.Decimal(-71.1909) }
  });
  const av1 = await prisma.availability.create({
    data: { propertyId: prop1.id, suite: 'Suite 500', rsf: 12000, askingRentPsf: new prisma.Prisma.Decimal(38), leaseType: 'NNN', nnnPsf: new prisma.Prisma.Decimal(12), freeRentMonths: 3, escalationPct: new prisma.Prisma.Decimal(3), termMin: 60, termMax: 96 }
  });

  const prop2 = await prisma.property.create({
    data: { orgId: org.id, address1: '5 Tech Park', city: 'Woburn', state: 'MA', postalCode: '01801', submarket: 'Burlington/Woburn', propertyType: 'Office', rsfTotal: 90000, lat: new prisma.Prisma.Decimal(42.4793), lng: new prisma.Prisma.Decimal(-71.1523) }
  });
  const av2 = await prisma.availability.create({
    data: { propertyId: prop2.id, suite: 'Suite 300', rsf: 10000, askingRentPsf: new prisma.Prisma.Decimal(36), leaseType: 'Gross', opExPsf: new prisma.Prisma.Decimal(0) }
  });

  const sl = await prisma.shortlist.create({ data: { dealId: deal.id, name: 'Initial Shortlist' } });
  await prisma.shortlistItem.create({ data: { shortlistId: sl.id, propertyId: prop1.id, availabilityId: av1.id } });
  await prisma.shortlistItem.create({ data: { shortlistId: sl.id, propertyId: prop2.id, availabilityId: av2.id } });

  console.log('Seeded org/users/client/deal, properties/availabilities, and a shortlist.');
}
main().catch((e) => { console.error(e); process.exit(1); }).finally(async () => { await prisma.$disconnect(); });

// Create a sample tour using the two properties
const tour = await prisma.tour.create({
  data: { dealId: deal.id, tourDate: new Date(), notes: 'Initial site tour' }
});
await prisma.tourStop.create({ data: { tourId: tour.id, propertyId: prop1.id, availabilityId: av1.id, stopOrder: 1 } });
await prisma.tourStop.create({ data: { tourId: tour.id, propertyId: prop2.id, availabilityId: av2.id, stopOrder: 2 } });
console.log('Seeded a sample tour with 2 stops.');

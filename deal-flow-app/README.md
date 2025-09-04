# WRA Deal Flow — Starter (Next.js + Prisma + Tailwind)

Internal **Deal Flow Analysis** app (AnthemIQ-inspired). This build includes:
- App Router + TypeScript + Tailwind
- Prisma schema (Deals, Properties, Availabilities, Shortlists, Tours, LOIs, Comps, etc.)
- **Pipeline** board, **Deal** detail
- **Compare Matrix** with ER/NPV (scenario bar)
- **LOI Builder** with tokenized template + server action save
- Docker Compose for Postgres + seed

## Quick start
```bash
pnpm i   # or npm i / yarn
docker compose up -d
cp .env.example .env
pnpm db:push
pnpm db:seed
pnpm dev
# http://localhost:3000
```

### Compare Matrix
- Navigate to **Shortlists → Open Compare**.
- Adjust scenario: RSF, Term, Start Rent, Escalation, Free Rent, TI, Discount, Lease Type, Ops.
- ER = NPV-based $/RSF/Yr including concessions & ops (see `lib/finance.ts`).

### LOI Builder
- From a Deal, click **Open LOI Builder**.
- Enter terms; preview updates live. Click **Save Draft** to persist (Draft LOI + key-value terms).
- Use browser **Print → Save as PDF** for a quick export (dedicated PDF export can be added later).

## Stack
- Next.js 14, React 18, Tailwind
- Prisma + PostgreSQL (via Docker)
- Minimal server actions; expand to API routes as needed.

## CSV Importers
- **Properties:** `/import/properties` — upsert by address (address1, city, state, postalCode).
- **Availabilities:** `/import/availabilities` — matches property by address (creates if missing).
- **Comps:** `/import/comps` — matches property by address (creates if missing).
Templates: see **/public/csv-templates/** or navigate to **/import** to download.

## Print‑ready Tour Book
- Go to **Tours → Print Tour Book** for any tour: `/tours/{id}/print`.
- Optimized for **Print → Save as PDF**. Includes cover, itinerary, per‑stop facts, and notes area.


## Column Mapping + Validation (Importers)
- Open **/import/** → choose an importer → upload any CSV → map your columns to the required fields.
- Server validates with **Zod** and returns a summary: created/updated counts plus sample row errors.
- You can still use the quick template import by posting the template CSVs to the original endpoints.

## Tour Route Optimization
- Each tour can be optimized via **Nearest Neighbor** heuristic to reorder stops.
- Use the **Optimize Route** button on the Tours list or on the Tour Book page.
- Requires properties to have **lat/lng** set (included in seed).

## Map Insets (Tour Book)
- The print view shows static map images for each stop.
- Set **NEXT_PUBLIC_MAPBOX_TOKEN** in `.env.local` to enable static map images.

Example `.env.local`:
```
NEXT_PUBLIC_MAPBOX_TOKEN=pk.your_mapbox_access_token_here
```

## Row‑level error CSV (Importers)
- After validation, you’ll see an **Errors** panel with the first 50 errors and a **Download Error CSV** button for the full list.

## PDF Export (branding included)
- **Compare Matrix**: From the compare page, click **Export PDF** — it renders the print view with WRA logo and downloads a PDF.
- **Tour Book**: On the print page, click **Export PDF** to download a branded PDF.
- Uses **Puppeteer** under `/api/export/pdf`. If running on Linux, Puppeteer launches with `--no-sandbox` by default.

## Tour Book Cover Page — Photo Montage
- Upload photos per property at: `/properties/{propertyId}/photos` (stored under `/public/uploads` and tracked as `Document` records).
- The Tour Book print view uses up to **6 images** from tour properties for a branded **cover montage**.
- If a property has no photo, we fall back to a **Mapbox static map** (set `NEXT_PUBLIC_MAPBOX_TOKEN`).


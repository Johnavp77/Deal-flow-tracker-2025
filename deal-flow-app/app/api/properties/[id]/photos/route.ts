import { NextResponse } from 'next/server'
import { prisma } from '@/lib/db'
import { promises as fs } from 'fs'
import path from 'path'

export async function POST(req: Request, { params }: { params: { id: string } }) {
  const form = await req.formData()
  const file = form.get('file') as File | null
  if (!file) return NextResponse.json({ error: 'No file provided' }, { status: 400 })

  const prop = await prisma.property.findUnique({ where: { id: params.id } })
  if (!prop) return NextResponse.json({ error: 'Property not found' }, { status: 404 })

  const arrayBuffer = await file.arrayBuffer()
  const bytes = new Uint8Array(arrayBuffer)

  const safeName = (file.name || 'upload').replace(/[^a-zA-Z0-9_.-]/g, '_')
  const relDir = `/uploads`
  const relPath = `${relDir}/property-${params.id}-${Date.now()}-${safeName}`
  const absPath = path.join(process.cwd(), 'public', relPath)

  await fs.mkdir(path.dirname(absPath), { recursive: true })  # placeholder replaced below
  await fs.writeFile(absPath, bytes)

  await prisma.document.create({
    data: {
      entityType: 'Property',
      entityId: params.id,
      fileUrl: relPath,
      kind: 'photo'
    }
  })
  return NextResponse.json({ ok: true, fileUrl: relPath })
}

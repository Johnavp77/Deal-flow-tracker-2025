import { NextResponse } from 'next/server'
import puppeteer from 'puppeteer'

export async function POST(req: Request) {
  const { path, filename } = await req.json()
  if (!path || typeof path !== 'string') return NextResponse.json({ error: 'path is required' }, { status: 400 })

  // simple allowlist
  const allowedPrefixes = ['/tours/', '/shortlists/']
  if (!allowedPrefixes.some(p => path.startsWith(p))) {
    return NextResponse.json({ error: 'Path not allowed' }, { status: 400 })
  }

  const host = req.headers.get('x-forwarded-host') || req.headers.get('host')
  const proto = req.headers.get('x-forwarded-proto') || 'http'
  const origin = `${proto}://${host}`
  const url = path.startsWith('http') ? path : `${origin}${path}`

  const browser = await puppeteer.launch({ args: ['--no-sandbox','--disable-setuid-sandbox'] })
  try {
    const page = await browser.newPage()
    await page.setViewport({ width: 1240, height: 1754, deviceScaleFactor: 1 }) // A4-ish
    await page.goto(url, { waitUntil: 'networkidle0', timeout: 120000 })
    const pdf = await page.pdf({
      printBackground: true,
      format: 'A4',
      margin: { top: '12mm', right: '12mm', bottom: '12mm', left: '12mm' }
    })
    const fname = filename || 'export.pdf'
    return new NextResponse(pdf, {
      status: 200,
      headers: {
        'Content-Type': 'application/pdf',
        'Content-Disposition': `attachment; filename="${fname}"`
      }
    })
  } finally {
    await browser.close()
  }
}

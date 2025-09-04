import './globals.css'
import Link from 'next/link'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <div className="min-h-screen grid grid-cols-[260px_1fr]">
          <aside className="bg-slate-50 border-r border-slate-200 p-4">
            <div className="font-bold text-wraBlue mb-4">WRA Deal Flow</div>
            <nav className="flex flex-col gap-2 text-sm">
              {['pipeline','deals','properties','shortlists','tours','lois','comps','analytics','import','tasks','settings'].map((p) => (
                <Link key={p} className="hover:underline" href={`/${p}`}>{p[0].toUpperCase()+p.slice(1)}</Link>
              ))}
            </nav>
          </aside>
          <main>{children}</main>
        </div>
      </body>
    </html>
  )
}

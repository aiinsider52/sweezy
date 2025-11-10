"use client"
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'

const items = [
  { href: '/admin/dashboard', label: 'Dashboard' },
  { href: '/admin/users', label: 'Users' },
  { href: '/admin/guides', label: 'Guides' },
  { href: '/admin/templates', label: 'Templates' },
  { href: '/admin/checklists', label: 'Checklists' },
  { href: '/admin/news', label: 'News' },
  { href: '/admin/appointments', label: 'Appointments' },
  { href: '/admin/config', label: 'Config' },
  { href: '/admin/monitoring', label: 'Monitoring' }
]

export default function Sidebar() {
  const pathname = usePathname()
  return (
    <aside className="w-72 p-6 space-y-4 sticky top-0 h-screen">
      <div className="glass p-5">
        <div className="text-lg font-semibold">Sweezy Admin</div>
        <div className="text-xs opacity-60">Swiss minimal</div>
      </div>
      <nav className="glass p-2 flex flex-col gap-1">
        {items.map(it => (
          <Link
            key={it.href}
            href={it.href}
            className={cn('flex items-center gap-2 rounded-lg px-3 py-2 hover:bg-white/10 transition', pathname?.startsWith(it.href) && 'bg-white/15')}
          >
            <span className="w-4 h-4 rounded-sm bg-white/20 mr-1.5" aria-hidden="true" /> {it.label}
          </Link>
        ))}
      </nav>
    </aside>
  )
}



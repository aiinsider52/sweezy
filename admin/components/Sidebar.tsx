"use client"
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'

const items = [
  { href: '/admin/dashboard', label: 'Dashboard' },
  { href: '/admin/users', label: 'Users' },
  { href: '/admin/monitoring', label: 'Monitoring' }
]

export default function Sidebar() {
  const pathname = usePathname()
  return (
    <aside className="w-60 p-4 space-y-2">
      <div className="glass p-4">
        <div className="text-lg font-semibold">Sweezy Admin</div>
      </div>
      <nav className="glass p-2">
        {items.map(it => (
          <Link
            key={it.href}
            href={it.href}
            className={cn('block rounded-md px-3 py-2 hover:bg-white/10', pathname?.startsWith(it.href) && 'bg-white/10')}
          >
            {it.label}
          </Link>
        ))}
      </nav>
    </aside>
  )
}



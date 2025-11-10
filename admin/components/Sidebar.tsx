"use client"
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'
import { LayoutDashboard, Users, BookOpenText, FileText, Activity, CheckSquare, Calendar, SlidersHorizontal, Newspaper } from 'lucide-react'

const items = [
  { href: '/admin/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/admin/users', label: 'Users', icon: Users },
  { href: '/admin/guides', label: 'Guides', icon: BookOpenText },
  { href: '/admin/templates', label: 'Templates', icon: FileText },
  { href: '/admin/checklists', label: 'Checklists', icon: CheckSquare },
  { href: '/admin/news', label: 'News', icon: Newspaper },
  { href: '/admin/appointments', label: 'Appointments', icon: Calendar },
  { href: '/admin/config', label: 'Config', icon: SlidersHorizontal },
  { href: '/admin/monitoring', label: 'Monitoring', icon: Activity }
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
            <it.icon size={16} aria-hidden="true" /> {it.label}
          </Link>
        ))}
      </nav>
    </aside>
  )
}



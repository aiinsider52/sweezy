"use client"
import Link from 'next/link'
import { useEffect, useMemo, useState } from 'react'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'
import { LayoutDashboard, Users, BookOpenText, FileText, Activity, CheckSquare, Calendar, SlidersHorizontal, Newspaper, Rss, ListChecks, Languages, Briefcase, CreditCard, Store, CalendarDays, Sparkles, MessageCircleQuestion, ShieldAlert, Siren, BarChart3 } from 'lucide-react'

const items = [
  { href: '/admin/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/admin/analytics', label: 'Analytics', icon: BarChart3 },
  { href: '/admin/users', label: 'Users', icon: Users },
  { href: '/admin/guides', label: 'Guides', icon: BookOpenText },
  { href: '/admin/templates', label: 'Templates', icon: FileText },
  { href: '/admin/checklists', label: 'Checklists', icon: CheckSquare },
  { href: '/admin/news', label: 'News', icon: Newspaper },
  { href: '/admin/rss-feeds', label: 'RSS Feeds', icon: Rss },
  { href: '/admin/subscriptions', label: 'Subscriptions', icon: CreditCard },
  { href: '/admin/audit-logs', label: 'Audit', icon: ListChecks },
  { href: '/admin/incidents', label: 'Incidents', icon: Siren },
  { href: '/admin/translations', label: 'Translations', icon: Languages },
  { href: '/admin/glossary', label: 'Glossary', icon: Languages },
  { href: '/admin/jobs', label: 'Jobs', icon: Briefcase },
  { href: '/admin/marketplace', label: 'Marketplace', icon: Store },
  { href: '/admin/chat-reports', label: 'Chat Safety', icon: ShieldAlert },
  { href: '/admin/expert-questions', label: 'Expert Q&A', icon: MessageCircleQuestion },
  { href: '/admin/moments', label: 'Swiss Moments', icon: Sparkles },
  { href: '/admin/events', label: 'Events', icon: CalendarDays },
  { href: '/admin/appointments', label: 'Appointments', icon: Calendar },
  { href: '/admin/config', label: 'Config', icon: SlidersHorizontal },
  { href: '/admin/monitoring', label: 'Monitoring', icon: Activity }
]

export default function Sidebar() {
  const pathname = usePathname()
  const [pendingMarketplaceIds, setPendingMarketplaceIds] = useState<string[]>([])
  const [unseenMarketplaceCount, setUnseenMarketplaceCount] = useState(0)

  useEffect(() => {
    let cancelled = false

    async function loadMarketplacePending() {
      try {
        const res = await fetch('/api/admin/marketplace', { cache: 'no-store' })
        const data = await res.json().catch(() => [])
        if (!Array.isArray(data) || cancelled) return
        const pendingIds = data
          .filter((item: { status?: string; id?: string }) => item?.status === 'pending' && item?.id)
          .map((item: { id: string }) => item.id)

        setPendingMarketplaceIds(pendingIds)

        if (typeof window !== 'undefined') {
          const seen = JSON.parse(localStorage.getItem('marketplace_seen_pending_ids') || '[]') as string[]
          const unseen = pendingIds.filter(id => !seen.includes(id))
          setUnseenMarketplaceCount(unseen.length)
        }
      } catch {
        if (!cancelled) setPendingMarketplaceIds([])
      }
    }

    loadMarketplacePending()
    const interval = window.setInterval(loadMarketplacePending, 30000)
    return () => {
      cancelled = true
      window.clearInterval(interval)
    }
  }, [])

  useEffect(() => {
    if (!pathname?.startsWith('/admin/marketplace') || typeof window === 'undefined') return
    localStorage.setItem('marketplace_seen_pending_ids', JSON.stringify(pendingMarketplaceIds))
    setUnseenMarketplaceCount(0)
  }, [pathname, pendingMarketplaceIds])

  const marketplacePendingCount = useMemo(() => pendingMarketplaceIds.length, [pendingMarketplaceIds])

  return (
    <aside className="w-full space-y-3 p-4 lg:sticky lg:top-0 lg:h-screen lg:w-72 lg:space-y-4 lg:p-6">
      <div className="glass hidden p-5 lg:block">
        <div className="text-lg font-semibold">Sweezy Admin</div>
        <div className="text-xs opacity-60">Swiss minimal</div>
      </div>
      <nav className="glass flex gap-1 overflow-x-auto p-2 lg:flex-col lg:overflow-x-visible">
        {items.map(it => (
          <Link
            key={it.href}
            href={it.href}
            className={cn('flex shrink-0 items-center gap-2 rounded-lg px-3 py-2 transition hover:bg-white/10', pathname?.startsWith(it.href) && 'bg-white/15')}
          >
            <it.icon size={16} aria-hidden="true" />
            <span className="flex flex-1 items-center justify-between gap-2">
              <span>{it.label}</span>
              {it.href === '/admin/marketplace' && marketplacePendingCount > 0 && (
                <span className="flex items-center gap-2">
                  {unseenMarketplaceCount > 0 && <span className="h-2.5 w-2.5 rounded-full bg-red-500" />}
                  <span className="rounded-full bg-red-500/20 px-2 py-0.5 text-xs font-semibold text-red-200">
                    {marketplacePendingCount}
                  </span>
                </span>
              )}
            </span>
          </Link>
        ))}
      </nav>
    </aside>
  )
}


"use client"
import Link from 'next/link'
import { useEffect, useMemo, useState } from 'react'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'
import { LayoutDashboard, Users, BookOpenText, FileText, Activity, CheckSquare, Calendar, SlidersHorizontal, Newspaper, Rss, ListChecks, Languages, Briefcase, CreditCard, Store, CalendarDays, Sparkles, MessageCircleQuestion, ShieldAlert, Siren, BarChart3, ChevronDown } from 'lucide-react'

const groups = [
  {
    id: 'overview',
    label: 'Overview',
    items: [
      { href: '/admin/dashboard', label: 'Dashboard', icon: LayoutDashboard },
      { href: '/admin/analytics', label: 'Analytics', icon: BarChart3 },
      { href: '/admin/users', label: 'Users', icon: Users },
      { href: '/admin/subscriptions', label: 'Subscriptions', icon: CreditCard },
    ],
  },
  {
    id: 'content',
    label: 'Content',
    items: [
      { href: '/admin/guides', label: 'Guides', icon: BookOpenText },
      { href: '/admin/templates', label: 'Templates', icon: FileText },
      { href: '/admin/checklists', label: 'Checklists', icon: CheckSquare },
      { href: '/admin/news', label: 'News', icon: Newspaper },
      { href: '/admin/rss-feeds', label: 'RSS Feeds', icon: Rss },
      { href: '/admin/moments', label: 'Swiss Moments', icon: Sparkles },
      { href: '/admin/events', label: 'Events', icon: CalendarDays },
    ],
  },
  {
    id: 'operations',
    label: 'Operations',
    items: [
      { href: '/admin/jobs', label: 'Jobs', icon: Briefcase },
      { href: '/admin/marketplace', label: 'Marketplace', icon: Store },
      { href: '/admin/appointments', label: 'Appointments', icon: Calendar },
      { href: '/admin/expert-questions', label: 'Expert Q&A', icon: MessageCircleQuestion },
      { href: '/admin/reports-safety', label: 'Reports & Safety', icon: ShieldAlert },
    ],
  },
  {
    id: 'language',
    label: 'Language',
    items: [
      { href: '/admin/translations', label: 'Translations', icon: Languages },
      { href: '/admin/glossary', label: 'Glossary', icon: Languages },
    ],
  },
  {
    id: 'system',
    label: 'System',
    items: [
      { href: '/admin/incidents', label: 'Incidents', icon: Siren },
      { href: '/admin/audit-logs', label: 'Audit', icon: ListChecks },
      { href: '/admin/monitoring', label: 'Monitoring', icon: Activity },
      { href: '/admin/config', label: 'Config', icon: SlidersHorizontal },
    ],
  },
]

export default function Sidebar() {
  const pathname = usePathname()
  const [pendingMarketplaceIds, setPendingMarketplaceIds] = useState<string[]>([])
  const [openSafetyCount, setOpenSafetyCount] = useState(0)
  const [unseenMarketplaceCount, setUnseenMarketplaceCount] = useState(0)
  const [expanded, setExpanded] = useState<Set<string>>(() => {
    const activeGroup = groups.find(group => group.items.some(item => pathname?.startsWith(item.href)))?.id
    return new Set(['overview', ...(activeGroup && activeGroup !== 'overview' ? [activeGroup] : [])])
  })

  useEffect(() => {
    let cancelled = false

    async function loadMarketplacePending() {
      try {
        const [marketplaceRes, safetyRes] = await Promise.all([
          fetch('/api/admin/marketplace', { cache: 'no-store' }),
          fetch('/api/admin/reports-safety/stats', { cache: 'no-store' }),
        ])
        const data = await marketplaceRes.json().catch(() => [])
        const safetyData = await safetyRes.json().catch(() => ({}))
        if (!Array.isArray(data) || cancelled) return
        const pendingIds = data
          .filter((item: { status?: string; id?: string }) => item?.status === 'pending' && item?.id)
          .map((item: { id: string }) => item.id)

        setPendingMarketplaceIds(pendingIds)
        setOpenSafetyCount(Number(safetyData?.open || 0) + Number(safetyData?.reviewing || 0))

        if (typeof window !== 'undefined') {
          const seen = JSON.parse(localStorage.getItem('marketplace_seen_pending_ids') || '[]') as string[]
          const unseen = pendingIds.filter(id => !seen.includes(id))
          setUnseenMarketplaceCount(unseen.length)
        }
      } catch {
        if (!cancelled) { setPendingMarketplaceIds([]); setOpenSafetyCount(0) }
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
      <nav className="glass max-h-[calc(100vh-8rem)] overflow-y-auto p-2">
        {groups.map(group => {
          const isExpanded = expanded.has(group.id)
          const hasActiveItem = group.items.some(item => pathname?.startsWith(item.href))
          return (
            <div key={group.id} className="border-b border-white/[.06] py-1 last:border-0">
              <button
                type="button"
                onClick={() => setExpanded(current => {
                  const next = new Set(current)
                  if (next.has(group.id)) next.delete(group.id)
                  else next.add(group.id)
                  return next
                })}
                className="flex w-full items-center justify-between rounded-lg px-3 py-2 text-left text-[11px] font-semibold uppercase tracking-[0.16em] text-white/45 transition hover:bg-white/[.06] hover:text-white/70"
                aria-expanded={isExpanded}
              >
                <span className={hasActiveItem ? 'text-cyan-300/80' : undefined}>{group.label}</span>
                <ChevronDown size={14} className={cn('transition-transform', isExpanded && 'rotate-180')} />
              </button>
              {isExpanded && (
                <div className="space-y-0.5 pb-1">
                  {group.items.map(it => (
                    <Link
                      key={it.href}
                      href={it.href}
                      className={cn('flex items-center gap-2 rounded-lg px-3 py-2 text-sm transition hover:bg-white/10', pathname?.startsWith(it.href) && 'bg-white/15 text-white')}
                    >
                      <it.icon size={16} aria-hidden="true" />
                      <span className="flex flex-1 items-center justify-between gap-2">
                        <span>{it.label}</span>
                        {((it.href === '/admin/marketplace' && marketplacePendingCount > 0) || (it.href === '/admin/reports-safety' && openSafetyCount > 0)) && (
                          <span className="flex items-center gap-2">
                            {it.href === '/admin/marketplace' && unseenMarketplaceCount > 0 && <span className="h-2.5 w-2.5 rounded-full bg-red-500" />}
                            <span className="rounded-full bg-red-500/20 px-2 py-0.5 text-xs font-semibold text-red-200">
                              {it.href === '/admin/marketplace' ? marketplacePendingCount : openSafetyCount}
                            </span>
                          </span>
                        )}
                      </span>
                    </Link>
                  ))}
                </div>
              )}
            </div>
          )
        })}
      </nav>
    </aside>
  )
}

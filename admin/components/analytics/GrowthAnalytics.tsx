'use client'

import { useEffect, useState } from 'react'
import Card from '@/components/Card'

type Step = { step: string; users: number; rate: number }
type Source = { source: string; funnel: Step[]; retention: { d1: number | null; d7: number | null; d30: number | null } }
type Growth = { installs: number; sources: Source[]; top_keywords: { keyword_id: string; installs: number }[] }

const STEP_LABELS: Record<string, string> = {
  installs: 'Installs',
  onboarded: 'Onboarded',
  registered: 'Signed up',
  activated: 'Got value',
  paywall: 'Saw Plus',
  paid: 'Paid',
}

const pct = (value: number | null) => (value === null ? '—' : `${(value * 100).toFixed(1)}%`)

function sourceLabel(source: string) {
  if (source === 'organic') return 'Organic'
  if (source === 'unknown') return 'Unknown (before attribution)'
  if (source.startsWith('apple_search_ads:')) return `Apple Search Ads · campaign ${source.split(':')[1]}`
  return source === 'apple_search_ads' ? 'Apple Search Ads' : source
}

/** Acquisition → activation → payment per install source, with D1/D7/D30 retention. */
export default function GrowthAnalytics({ range }: { range: string }) {
  const [data, setData] = useState<Growth | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setError(null)
    fetch(`/api/admin/analytics/growth?range=${encodeURIComponent(range)}`, { cache: 'no-store' })
      .then(async response => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        return response.json() as Promise<Growth>
      })
      .then(body => { if (!cancelled) setData(body) })
      .catch(() => { if (!cancelled) setError('Growth analytics could not be loaded.') })
    return () => { cancelled = true }
  }, [range])

  if (error) return <Card title="Growth by source"><p className="text-sm text-red-200">{error}</p></Card>
  if (!data) return null
  if (!data.sources.length) {
    return (
      <Card title="Growth by source">
        <p className="text-sm text-white/55">No attributed installs yet. They appear once users on app 2.5+ open the app with analytics allowed.</p>
      </Card>
    )
  }

  return (
    <Card title={`Growth by source · ${data.installs.toLocaleString()} installs`}>
      <div className="space-y-5">
        {data.sources.map(source => (
          <div key={source.source} className="rounded-xl border border-white/10 bg-white/[.035] p-4">
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h3 className="font-medium">{sourceLabel(source.source)}</h3>
              <p className="text-xs text-white/50">
                Retention D1 {pct(source.retention.d1)} · D7 {pct(source.retention.d7)} · D30 {pct(source.retention.d30)}
              </p>
            </div>
            <div className="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
              {source.funnel.map(step => (
                <div key={step.step}>
                  <div className="flex justify-between text-xs text-white/55">
                    <span>{STEP_LABELS[step.step] ?? step.step}</span>
                    <span>{pct(step.rate)}</span>
                  </div>
                  <strong className="mt-1 block text-xl">{step.users.toLocaleString()}</strong>
                  <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-white/10">
                    <div className="h-full rounded-full bg-lime-300" style={{ width: `${Math.min(100, step.rate * 100)}%` }} />
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
        {data.top_keywords.length > 0 && (
          <div>
            <p className="mb-2 text-xs uppercase tracking-wide text-white/50">Top Search Ads keywords (ids)</p>
            <div className="flex flex-wrap gap-2">
              {data.top_keywords.map(item => (
                <span key={item.keyword_id} className="rounded-full border border-white/10 px-3 py-1 text-xs">
                  {item.keyword_id} · {item.installs}
                </span>
              ))}
            </div>
          </div>
        )}
      </div>
    </Card>
  )
}

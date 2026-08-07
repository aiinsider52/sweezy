'use client'

import { useCallback, useEffect, useState } from 'react'
import { AlertCircle, RefreshCw, UserPlus } from 'lucide-react'
import Card from '@/components/Card'
import Skeleton from '@/components/Skeleton'
import UISelect from '@/components/ui/select'
import { TrendChart, type ChartPoint } from './AnalyticsCharts'

type RegistrationsPayload = {
  today: number
  last_7d: number
  last_30d: number
  total_in_range: number
  avg_per_day: number
  delta_7d_percent?: number | null
  trends: ChartPoint[]
}

const ranges = [
  { value: '7d', label: 'Last 7 days' },
  { value: '30d', label: 'Last 30 days' },
  { value: '90d', label: 'Last 90 days' },
  { value: '365d', label: 'Last 12 months' },
]

export default function RegistrationsAnalytics({ compact = false }: { compact?: boolean }) {
  const [range, setRange] = useState('30d')
  const [data, setData] = useState<RegistrationsPayload | null>(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const response = await fetch(`/api/admin/users/registrations?range=${range}`, { cache: 'no-store' })
      if (!response.ok) {
        const body = await response.json().catch(() => ({}))
        throw new Error(body.detail || `Request failed (${response.status})`)
      }
      const payload = await response.json()
      setData({
        today: Number(payload.today ?? 0),
        last_7d: Number(payload.last_7d ?? 0),
        last_30d: Number(payload.last_30d ?? 0),
        total_in_range: Number(payload.total_in_range ?? 0),
        avg_per_day: Number(payload.avg_per_day ?? 0),
        delta_7d_percent: payload.delta_7d_percent === undefined || payload.delta_7d_percent === null
          ? null
          : Number(payload.delta_7d_percent),
        trends: Array.isArray(payload.trends)
          ? payload.trends.map((row: { date?: string; count?: number }, index: number) => ({
              label: String(row.date ?? index + 1),
              value: Number(row.count ?? 0),
            }))
          : [],
      })
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Unable to load registrations.')
    } finally {
      setLoading(false)
    }
  }, [range])

  useEffect(() => { void load() }, [load])

  if (loading && !data) {
    return (
      <section className="space-y-4" aria-label="Loading registrations">
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {Array.from({ length: 4 }, (_, index) => <Skeleton key={index} className="h-28" />)}
        </div>
        <Skeleton className="h-80" />
      </section>
    )
  }

  const kpis = data ? [
    { label: 'Today', value: data.today },
    { label: 'Last 7 days', value: data.last_7d, delta: data.delta_7d_percent },
    { label: compact ? 'Last 30 days' : 'In selected range', value: compact ? data.last_30d : data.total_in_range },
    { label: 'Avg / day', value: data.avg_per_day },
  ] : []

  return (
    <section className="space-y-4">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-xs font-medium uppercase tracking-[0.22em] text-emerald-300">Growth</p>
          <h2 className="mt-1 text-xl font-semibold tracking-tight">User registrations</h2>
          <p className="mt-1 text-sm text-white/55">Daily account creations from signup timestamps.</p>
        </div>
        <div className="flex gap-2">
          <UISelect value={range} onChange={setRange} options={ranges} className="w-40" />
          <button onClick={() => void load()} className="glass inline-flex min-h-10 items-center justify-center gap-2 px-3 text-sm hover:bg-white/10" aria-label="Refresh registrations">
            <RefreshCw size={15} className={loading ? 'animate-spin' : ''} /> Refresh
          </button>
        </div>
      </div>

      {error && (
        <div className="flex items-center justify-between gap-4 rounded-xl border border-red-400/25 bg-red-500/10 p-4 text-sm text-red-100" role="alert">
          <span className="flex items-center gap-2"><AlertCircle size={17} />{error}</span>
          <button onClick={() => void load()} className="font-medium underline underline-offset-4">Try again</button>
        </div>
      )}

      {data && (
        <>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            {kpis.map(metric => (
              <div key={metric.label} className="glass relative overflow-hidden p-5">
                <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-emerald-300/70 to-transparent" />
                <p className="text-sm text-white/55">{metric.label}</p>
                <div className="mt-2 flex items-end justify-between gap-3">
                  <strong className="text-3xl font-semibold tracking-tight">
                    {metric.value.toLocaleString(undefined, { maximumFractionDigits: metric.label === 'Avg / day' ? 1 : 0 })}
                  </strong>
                  {'delta' in metric && metric.delta !== null && metric.delta !== undefined && (
                    <span className={`text-xs font-medium ${metric.delta >= 0 ? 'text-emerald-300' : 'text-rose-300'}`}>
                      {metric.delta >= 0 ? '+' : ''}{metric.delta}% WoW
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>

          <Card title="Registrations by day">
            {data.trends.length > 0 ? (
              <TrendChart data={data.trends} />
            ) : (
              <div className="py-12 text-center text-sm text-white/50">
                <UserPlus className="mx-auto mb-2 text-white/30" size={28} />
                No registrations in this period.
              </div>
            )}
          </Card>
        </>
      )}
    </section>
  )
}

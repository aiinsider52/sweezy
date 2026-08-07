'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import { Activity, AlertCircle, ArrowDownRight, ArrowUpRight, RefreshCw } from 'lucide-react'
import Card from '@/components/Card'
import Skeleton from '@/components/Skeleton'
import UISelect from '@/components/ui/select'
import { RankingChart, TrendChart, type ChartPoint } from './AnalyticsCharts'
import RegistrationsAnalytics from './RegistrationsAnalytics'

type Metric = { key: string; label: string; value: number; delta?: number; format?: string }
type FunnelStep = { label: string; value: number }
type AnalyticsData = {
  kpis: Metric[]
  trends: ChartPoint[]
  top: ChartPoint[]
  funnels: FunnelStep[]
  versions: string[]
}

const ranges = [
  { value: '7d', label: 'Last 7 days' },
  { value: '30d', label: 'Last 30 days' },
  { value: '90d', label: 'Last 90 days' },
  { value: '365d', label: 'Last 12 months' },
]

const asNumber = (value: unknown) => Number.isFinite(Number(value)) ? Number(value) : 0
const asRecord = (value: unknown): Record<string, unknown> =>
  value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : {}

function points(value: unknown): ChartPoint[] {
  if (!Array.isArray(value)) return []
  return value.map((item, index) => {
    const row = asRecord(item)
    return {
      label: String(row.label ?? row.date ?? row.name ?? row.period ?? index + 1),
      value: asNumber(row.value ?? row.count ?? row.events ?? row.users ?? row.views),
      secondary: row.secondary === undefined
        ? (row.sessions === undefined ? undefined : asNumber(row.sessions))
        : asNumber(row.secondary),
    }
  })
}

function normalize(payload: unknown): AnalyticsData {
  const root = asRecord(payload)
  const data = asRecord(root.data ?? root)
  const rawVersions = data.versions ?? data.app_versions
  const rawKpis = data.kpis ?? data.metrics ?? data.overview
  const kpis: Metric[] = Array.isArray(rawKpis)
    ? rawKpis.map((item, index) => {
        const row = asRecord(item)
        return {
          key: String(row.key ?? row.label ?? index),
          label: String(row.label ?? row.name ?? row.key ?? 'Metric'),
          value: asNumber(row.value ?? row.count),
          delta: row.delta === undefined ? undefined : asNumber(row.delta),
          format: typeof row.format === 'string' ? row.format : undefined,
        }
      })
    : Object.entries(asRecord(rawKpis)).map(([key, value]) => ({
        key,
        label: key.replaceAll('_', ' ').replace(/\b\w/g, letter => letter.toUpperCase()),
        value: asNumber(asRecord(value).value ?? value),
        delta: asRecord(value).delta === undefined ? undefined : asNumber(asRecord(value).delta),
      }))

  const rawFunnels = data.funnels ?? data.funnel
  const funnelArray = Array.isArray(rawFunnels)
    ? rawFunnels
    : Object.entries(asRecord(rawFunnels)).map(([label, value]) => ({ label, value }))

  return {
    kpis,
    trends: points(data.trends ?? data.trend ?? data.timeseries),
    top: points(data.top ?? data.top_content ?? data.rankings),
    funnels: funnelArray.map((item, index) => {
      const row = asRecord(item)
      return { label: String(row.label ?? row.name ?? row.step ?? index + 1), value: asNumber(row.value ?? row.count) }
    }),
    versions: Array.isArray(rawVersions) ? rawVersions.map(String) : [],
  }
}

function formatMetric(metric: Metric) {
  if (metric.format === 'percent') return `${metric.value.toLocaleString(undefined, { maximumFractionDigits: 1 })}%`
  if (metric.format === 'currency') return new Intl.NumberFormat(undefined, { style: 'currency', currency: 'CHF', maximumFractionDigits: 0 }).format(metric.value)
  return metric.value.toLocaleString()
}

export default function AnalyticsDashboard({ compact = false }: { compact?: boolean }) {
  const [range, setRange] = useState('30d')
  const [version, setVersion] = useState('all')
  const [data, setData] = useState<AnalyticsData | null>(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const query = new URLSearchParams({ range })
      if (version !== 'all') query.set('app_version', version)
      const response = await fetch(`/api/admin/analytics?${query}`, { cache: 'no-store' })
      if (!response.ok) {
        const body = await response.json().catch(() => ({}))
        throw new Error(body.detail || `Request failed (${response.status})`)
      }
      setData(normalize(await response.json()))
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Unable to load analytics.')
    } finally {
      setLoading(false)
    }
  }, [range, version])

  useEffect(() => { void load() }, [load])

  const versionOptions = useMemo(() => [
    { value: 'all', label: 'All versions' },
    ...(data?.versions ?? []).map(item => ({ value: item, label: `Version ${item}` })),
  ], [data?.versions])

  if (loading && !data) return <AnalyticsLoading />

  return (
    <section className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-xs font-medium uppercase tracking-[0.22em] text-cyan-300">Product intelligence</p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight sm:text-3xl">{compact ? 'At a glance' : 'Analytics'}</h1>
          <p className="mt-1 text-sm text-white/55">Aggregate usage signals, content performance, and conversion.</p>
        </div>
        <div className="flex flex-col gap-2 xs:flex-row sm:flex-row">
          <UISelect value={range} onChange={setRange} options={ranges} className="w-full sm:w-40" />
          <UISelect value={version} onChange={setVersion} options={versionOptions} className="w-full sm:w-40" />
          <button onClick={() => void load()} className="glass inline-flex min-h-10 items-center justify-center gap-2 px-3 text-sm hover:bg-white/10" aria-label="Refresh analytics">
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

      {data && data.kpis.length > 0 && (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {data.kpis.slice(0, compact ? 4 : 8).map(metric => (
            <div key={metric.key} className="glass relative overflow-hidden p-5">
              <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-cyan-300/70 to-transparent" />
              <p className="text-sm text-white/55">{metric.label}</p>
              <div className="mt-2 flex items-end justify-between gap-3">
                <strong className="text-3xl font-semibold tracking-tight">{formatMetric(metric)}</strong>
                {metric.delta !== undefined && (
                  <span className={`flex items-center text-xs font-medium ${metric.delta >= 0 ? 'text-emerald-300' : 'text-rose-300'}`}>
                    {metric.delta >= 0 ? <ArrowUpRight size={14} /> : <ArrowDownRight size={14} />}
                    {Math.abs(metric.delta)}%
                  </span>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {data && !data.kpis.length && !data.trends.length && !data.top.length && !data.funnels.length && !error && (
        <Card className="py-16 text-center">
          <Activity className="mx-auto text-white/30" size={30} />
          <h2 className="mt-3 font-medium">No analytics for this period</h2>
          <p className="mt-1 text-sm text-white/50">Try a wider date range or another app version.</p>
        </Card>
      )}

      {data && (data.trends.length > 0 || data.top.length > 0) && (
        <div className="grid grid-cols-1 gap-6 xl:grid-cols-5">
          {data.trends.length > 0 && <Card title="Usage trend" className="xl:col-span-3"><TrendChart data={data.trends} /></Card>}
          {data.top.length > 0 && <Card title="Top content" className="xl:col-span-2"><RankingChart data={data.top.slice(0, 8)} /></Card>}
        </div>
      )}

      <RegistrationsAnalytics compact={compact} />

      {!compact && data && data.funnels.length > 0 && (
        <Card title="Conversion funnel">
          <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
            {data.funnels.map((step, index) => {
              const first = data.funnels[0]?.value || 0
              const rate = first ? (step.value / first) * 100 : 0
              return (
                <div key={`${step.label}-${index}`} className="rounded-xl border border-white/10 bg-white/[.035] p-4">
                  <div className="flex justify-between gap-3 text-sm"><span>{step.label}</span><span className="text-white/45">{rate.toFixed(1)}%</span></div>
                  <strong className="mt-2 block text-2xl">{step.value.toLocaleString()}</strong>
                  <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-white/10"><div className="h-full rounded-full bg-cyan-400" style={{ width: `${rate}%` }} /></div>
                </div>
              )
            })}
          </div>
        </Card>
      )}
    </section>
  )
}

function AnalyticsLoading() {
  return (
    <section className="space-y-6" aria-label="Loading analytics">
      <div className="flex justify-between"><Skeleton className="h-14 w-64" /><Skeleton className="h-10 w-72" /></div>
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{Array.from({ length: 4 }, (_, index) => <Skeleton key={index} className="h-32" />)}</div>
      <div className="grid gap-6 xl:grid-cols-5"><Skeleton className="h-80 xl:col-span-3" /><Skeleton className="h-80 xl:col-span-2" /></div>
    </section>
  )
}

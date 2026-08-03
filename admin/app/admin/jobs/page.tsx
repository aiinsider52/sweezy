'use client'

import { useCallback, useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { AlertTriangle, Building2, CheckCircle2, Database, RefreshCw, ShieldCheck, XCircle } from 'lucide-react'
import Card from '@/components/Card'

type Provider = {
  provider: string
  configured: boolean
  status: string
  last_success_at?: string
  last_item_count: number
  message?: string
}

type Job = {
  id: string
  title: string
  company?: string
  location?: string
  canton?: string
  source: string
  status?: string
  posted_at?: string
}

type Employer = {
  user_id: string
  company_name: string
  canton: string
  contact_name: string
  contact_email: string
  is_verified: boolean
}

type Report = {
  id: string
  job_id: string
  reason: string
  details?: string
  created_at: string
}

async function readJSON<T>(url: string): Promise<T> {
  const response = await fetch(url, { cache: 'no-store' })
  const body = await response.text()
  if (!response.ok) throw new Error(body || `HTTP ${response.status}`)
  return JSON.parse(body) as T
}

export default function JobsOperationsPage() {
  const [providers, setProviders] = useState<Provider[]>([])
  const [pending, setPending] = useState<Job[]>([])
  const [employers, setEmployers] = useState<Employer[]>([])
  const [reports, setReports] = useState<Report[]>([])
  const [busy, setBusy] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setError(null)
    try {
      const [sourceData, pendingData, employerData, reportData] = await Promise.all([
        readJSON<Provider[]>('/api/admin/jobs/sources'),
        readJSON<Job[]>('/api/admin/jobs/pending'),
        readJSON<Employer[]>('/api/admin/jobs/employers'),
        readJSON<Report[]>('/api/admin/jobs/reports?status=open'),
      ])
      setProviders(sourceData)
      setPending(pendingData)
      setEmployers(employerData)
      setReports(reportData)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Jobs dashboard unavailable')
    }
  }, [])

  useEffect(() => { void load() }, [load])

  async function mutate(key: string, url: string) {
    setBusy(key)
    setError(null)
    try {
      const response = await fetch(url, { method: 'POST' })
      if (!response.ok) throw new Error(await response.text())
      await load()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Action failed')
    } finally {
      setBusy(null)
    }
  }

  const totalImported = providers.reduce((sum, item) => sum + item.last_item_count, 0)
  const healthy = providers.filter(item => item.status === 'healthy').length

  return (
    <div className="p-6 space-y-5">
      <header className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div>
          <p className="text-xs uppercase tracking-[0.24em] opacity-50">Sweezy Jobs Operations</p>
          <h1 className="mt-2 text-3xl font-semibold">Каталог, модерація, довіра</h1>
          <p className="mt-1 max-w-2xl text-sm opacity-60">Вакансії зберігаються в PostgreSQL. Цей екран керує синхронізацією джерел, роботодавцями й скаргами.</p>
        </div>
        <button
          onClick={() => mutate('sync', '/api/admin/jobs/sync')}
          disabled={busy !== null}
          className="glass inline-flex items-center justify-center gap-2 rounded-xl px-4 py-3 font-medium disabled:opacity-50"
        >
          <RefreshCw size={17} className={busy === 'sync' ? 'animate-spin' : ''} />
          Синхронізувати зараз
        </button>
      </header>

      {error && <div className="rounded-xl border border-red-400/30 bg-red-500/10 p-4 text-sm text-red-200">{error}</div>}

      <section className="grid gap-3 md:grid-cols-4">
        <Metric icon={<Database size={19} />} label="Останній імпорт" value={totalImported} />
        <Metric icon={<CheckCircle2 size={19} />} label="Здорові джерела" value={`${healthy}/${providers.length}`} />
        <Metric icon={<ShieldCheck size={19} />} label="На модерації" value={pending.length} />
        <Metric icon={<AlertTriangle size={19} />} label="Відкриті скарги" value={reports.length} />
      </section>

      <Card>
        <SectionTitle title="Джерела вакансій" subtitle="Jooble та офіційні ATS feeds. Помилка одного провайдера не зупиняє каталог." />
        <div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-4">
          {providers.map(provider => (
            <div key={provider.provider} className="glass rounded-xl p-4">
              <div className="flex items-center justify-between gap-3">
                <strong className="capitalize">{provider.provider}</strong>
                <Status value={provider.configured ? provider.status : 'disabled'} />
              </div>
              <div className="mt-4 text-2xl font-semibold">{provider.last_item_count}</div>
              <div className="text-xs opacity-50">вакансій в останньому sync</div>
              {provider.last_success_at && <div className="mt-3 text-xs opacity-50">{new Date(provider.last_success_at).toLocaleString()}</div>}
              {provider.message && <div className="mt-2 text-xs text-orange-300 line-clamp-3">{provider.message}</div>}
            </div>
          ))}
          {providers.length === 0 && <Empty text="Джерела ще не ініціалізовані. Запусти sync після додавання API keys або ATS board IDs." />}
        </div>
      </Card>

      <Card>
        <SectionTitle title="Вакансії на модерації" subtitle="Власні вакансії Sweezy не потрапляють у каталог до ручної перевірки." />
        <div className="mt-4 space-y-3">
          {pending.map(job => (
            <div key={job.id} className="glass flex flex-col gap-3 rounded-xl p-4 lg:flex-row lg:items-center">
              <div className="min-w-0 flex-1">
                <div className="font-medium">{job.title}</div>
                <div className="mt-1 text-sm opacity-60">{job.company || 'Компанія'} · {job.location || job.canton || 'Switzerland'}</div>
              </div>
              <button onClick={() => mutate(`approve-${job.id}`, `/api/admin/jobs/${job.id}/approve`)} disabled={busy !== null} className="rounded-lg bg-lime-300 px-4 py-2 text-sm font-semibold text-black disabled:opacity-50">Схвалити</button>
              <button onClick={() => mutate(`reject-${job.id}`, `/api/admin/jobs/${job.id}/reject?reason=${encodeURIComponent('Недостатньо даних або порушення правил')}`)} disabled={busy !== null} className="rounded-lg border border-red-400/30 px-4 py-2 text-sm text-red-200 disabled:opacity-50">Відхилити</button>
            </div>
          ))}
          {pending.length === 0 && <Empty text="Черга чиста." />}
        </div>
      </Card>

      <div className="grid gap-5 xl:grid-cols-2">
        <Card>
          <SectionTitle title="Роботодавці" subtitle="Verified badge відкриває сильніший trust signal, але вакансії все одно проходять модерацію." />
          <div className="mt-4 space-y-3">
            {employers.map(employer => (
              <div key={employer.user_id} className="glass flex items-center gap-3 rounded-xl p-4">
                <Building2 size={20} className="shrink-0 opacity-70" />
                <div className="min-w-0 flex-1">
                  <div className="truncate font-medium">{employer.company_name}</div>
                  <div className="truncate text-xs opacity-50">{employer.canton} · {employer.contact_email}</div>
                </div>
                {employer.is_verified ? <Status value="verified" /> : (
                  <button onClick={() => mutate(`verify-${employer.user_id}`, `/api/admin/jobs/employers/${employer.user_id}/verify`)} disabled={busy !== null} className="rounded-lg bg-white/10 px-3 py-2 text-xs disabled:opacity-50">Перевірити</button>
                )}
              </div>
            ))}
            {employers.length === 0 && <Empty text="Business accounts ще не створені." />}
          </div>
        </Card>

        <Card>
          <SectionTitle title="Скарги" subtitle="Підозрілі, неактуальні або оманливі вакансії." />
          <div className="mt-4 space-y-3">
            {reports.map(report => (
              <div key={report.id} className="glass flex items-center gap-3 rounded-xl p-4">
                <AlertTriangle size={20} className="shrink-0 text-orange-300" />
                <div className="min-w-0 flex-1">
                  <div className="font-medium">{report.reason}</div>
                  <div className="truncate text-xs opacity-50">Job {report.job_id} · {new Date(report.created_at).toLocaleString()}</div>
                </div>
                <button onClick={() => mutate(`resolve-${report.id}`, `/api/admin/jobs/reports/${report.id}/resolve`)} disabled={busy !== null} className="rounded-lg bg-white/10 px-3 py-2 text-xs disabled:opacity-50">Закрити</button>
              </div>
            ))}
            {reports.length === 0 && <Empty text="Відкритих скарг немає." />}
          </div>
        </Card>
      </div>
    </div>
  )
}

function Metric({ icon, label, value }: { icon: ReactNode, label: string, value: string | number }) {
  return <div className="glass rounded-2xl p-4"><div className="flex items-center gap-2 text-sm opacity-60">{icon}{label}</div><div className="mt-3 text-3xl font-semibold">{value}</div></div>
}

function SectionTitle({ title, subtitle }: { title: string, subtitle: string }) {
  return <div><h2 className="text-lg font-semibold">{title}</h2><p className="mt-1 text-sm opacity-55">{subtitle}</p></div>
}

function Status({ value }: { value: string }) {
  const good = ['healthy', 'verified'].includes(value)
  const bad = value === 'error'
  return <span className={`inline-flex items-center gap-1 rounded-full px-2 py-1 text-[11px] ${good ? 'bg-lime-300/15 text-lime-200' : bad ? 'bg-red-400/15 text-red-200' : 'bg-white/10 opacity-70'}`}>
    {bad ? <XCircle size={11} /> : <CheckCircle2 size={11} />}{value}
  </span>
}

function Empty({ text }: { text: string }) {
  return <div className="rounded-xl border border-dashed border-white/15 p-5 text-sm opacity-50">{text}</div>
}

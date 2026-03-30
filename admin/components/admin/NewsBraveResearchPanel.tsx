"use client"

import { useEffect, useMemo, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'react-hot-toast'

import Button from '@/components/ui/button'
import { Dialog } from '@/components/ui/dialog'
import UIInput from '@/components/ui/input'
import UISelect from '@/components/ui/select'
import type { BraveNewsQuery } from '@/lib/types'

type QueryFormState = {
  query: string
  language: string
  country: string
  status: 'draft' | 'published'
  enabled: boolean
  max_results: number
  freshness_days: number
}

const emptyForm: QueryFormState = {
  query: '',
  language: 'uk',
  country: 'CH',
  status: 'published',
  enabled: true,
  max_results: 8,
  freshness_days: 7,
}

async function fetchQueries(): Promise<BraveNewsQuery[]> {
  const res = await fetch('/api/admin/brave-news/queries', { cache: 'no-store' })
  if (!res.ok) throw new Error(await res.text())
  return res.json()
}

export default function NewsBraveResearchPanel() {
  const qc = useQueryClient()
  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<BraveNewsQuery | null>(null)
  const [loading, setLoading] = useState(false)
  const [runningAll, setRunningAll] = useState(false)
  const [form, setForm] = useState<QueryFormState>(emptyForm)

  const { data = [], isLoading } = useQuery({
    queryKey: ['brave-news-queries'],
    queryFn: fetchQueries,
  })

  useEffect(() => {
    if (!open) return
    if (!editing) {
      setForm(emptyForm)
      return
    }
    setForm({
      query: editing.query,
      language: editing.language ?? 'uk',
      country: editing.country ?? 'CH',
      status: editing.status ?? 'published',
      enabled: Boolean(editing.enabled),
      max_results: editing.max_results ?? 8,
      freshness_days: editing.freshness_days ?? 7,
    })
  }, [open, editing])

  const enabledCount = useMemo(() => data.filter(item => item.enabled).length, [data])

  async function refreshAll() {
    await qc.invalidateQueries({ queryKey: ['brave-news-queries'] })
    await qc.invalidateQueries({ queryKey: ['news'] })
  }

  async function submit() {
    if (!form.query.trim()) {
      toast.error('Query is required')
      return
    }
    setLoading(true)
    try {
      const payload = {
        query: form.query.trim(),
        language: form.language,
        country: form.country.trim().toUpperCase() || null,
        status: form.status,
        enabled: form.enabled,
        max_results: Number(form.max_results || 8),
        freshness_days: Number(form.freshness_days || 7),
      }
      const res = await fetch(
        editing ? `/api/admin/brave-news/queries/${editing.id}` : '/api/admin/brave-news/queries',
        {
          method: editing ? 'PATCH' : 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        }
      )
      const body = await res.json().catch(() => null)
      if (!res.ok) throw new Error(body?.detail || body?.error || 'Failed to save query')
      toast.success(editing ? 'Query updated' : 'Query created')
      setOpen(false)
      setEditing(null)
      await refreshAll()
    } catch (error: any) {
      toast.error(error?.message || 'Failed to save query')
    } finally {
      setLoading(false)
    }
  }

  async function runQuery(id: string) {
    try {
      const res = await fetch(`/api/admin/brave-news/queries/${id}/run`, { method: 'POST' })
      const body = await res.json().catch(() => null)
      if (!res.ok) throw new Error(body?.detail || 'Manual run failed')
      toast.success(`Imported ${body?.created ?? 0}, updated ${body?.updated ?? 0}, archived ${body?.archived ?? 0}`)
      await refreshAll()
    } catch (error: any) {
      toast.error(error?.message || 'Manual run failed')
    }
  }

  async function runAll() {
    setRunningAll(true)
    try {
      const res = await fetch('/api/admin/brave-news/run-all', { method: 'POST' })
      const body = await res.json().catch(() => null)
      if (!res.ok) throw new Error(body?.detail || 'Weekly refresh failed')
      toast.success(`Queries ${body?.queries ?? 0}, created ${body?.created ?? 0}, updated ${body?.updated ?? 0}`)
      await refreshAll()
    } catch (error: any) {
      toast.error(error?.message || 'Weekly refresh failed')
    } finally {
      setRunningAll(false)
    }
  }

  async function removeQuery(id: string) {
    if (!window.confirm('Delete this Brave research query?')) return
    try {
      const res = await fetch(`/api/admin/brave-news/queries/${id}`, { method: 'DELETE' })
      if (!res.ok) throw new Error(await res.text())
      toast.success('Query deleted')
      await refreshAll()
    } catch (error: any) {
      toast.error(error?.message || 'Delete failed')
    }
  }

  return (
    <div className="mb-6 rounded-2xl border border-white/10 bg-white/5 p-4 shadow-soft backdrop-blur-md">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <div className="text-lg font-semibold">Brave Research</div>
          <div className="mt-1 text-sm opacity-70">
            Weekly discovery for fresh external articles. Imported items stay as links and old Brave results auto-archive.
          </div>
          <div className="mt-3 flex flex-wrap gap-2 text-xs opacity-80">
            <span className="rounded-full border border-white/10 px-3 py-1">Queries: {data.length}</span>
            <span className="rounded-full border border-white/10 px-3 py-1">Enabled: {enabledCount}</span>
          </div>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button onClick={runAll} disabled={runningAll} className="px-3 py-2">
            {runningAll ? 'Running…' : 'Run Weekly Refresh'}
          </Button>
          <Button
            onClick={() => {
              setEditing(null)
              setOpen(true)
            }}
            className="px-3 py-2"
          >
            Add Query
          </Button>
        </div>
      </div>

      <div className="mt-4 overflow-x-auto rounded-xl border border-white/10 bg-black/10">
        <table className="min-w-full text-sm">
          <thead className="border-b border-white/10 text-left opacity-70">
            <tr>
              <th className="px-4 py-3">Query</th>
              <th className="px-4 py-3">Locale</th>
              <th className="px-4 py-3">Mode</th>
              <th className="px-4 py-3">Last run</th>
              <th className="px-4 py-3">Actions</th>
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr>
                <td className="px-4 py-6 text-center opacity-70" colSpan={5}>Loading…</td>
              </tr>
            ) : data.length === 0 ? (
              <tr>
                <td className="px-4 py-6 text-center opacity-70" colSpan={5}>No Brave queries yet</td>
              </tr>
            ) : (
              data.map(item => (
                <tr key={item.id} className="border-t border-white/5 align-top">
                  <td className="px-4 py-3">
                    <div className="font-medium">{item.query}</div>
                    <div className="mt-1 text-xs opacity-60">{item.enabled ? 'enabled' : 'paused'}</div>
                  </td>
                  <td className="px-4 py-3">
                    <div>{item.language.toUpperCase()}</div>
                    <div className="mt-1 text-xs opacity-60">{item.country || 'global'}</div>
                  </td>
                  <td className="px-4 py-3">
                    <div>{item.status}</div>
                    <div className="mt-1 text-xs opacity-60">
                      {item.max_results} results • {item.freshness_days}d window
                    </div>
                  </td>
                  <td className="px-4 py-3 text-xs opacity-70">
                    {item.last_imported_at ? new Date(item.last_imported_at).toLocaleString() : 'Never'}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex flex-wrap gap-2">
                      <Button onClick={() => runQuery(item.id)} className="px-2 py-1">Run</Button>
                      <Button
                        onClick={() => {
                          setEditing(item)
                          setOpen(true)
                        }}
                        className="px-2 py-1"
                      >
                        Edit
                      </Button>
                      <Button onClick={() => removeQuery(item.id)} className="px-2 py-1 text-red-400">
                        Delete
                      </Button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <Dialog open={open} onClose={() => setOpen(false)} size="lg">
        <div className="mb-3 text-lg font-medium">{editing ? 'Edit Brave Query' : 'Create Brave Query'}</div>
        <div className="grid gap-3">
          <div>
            <div className="mb-1 text-sm opacity-70">Search query</div>
            <UIInput
              placeholder='e.g. swiss immigration law updates site:admin.ch OR expat Switzerland jobs'
              value={form.query}
              onChange={e => setForm(prev => ({ ...prev, query: e.target.value }))}
            />
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <div className="mb-1 text-sm opacity-70">Language</div>
              <UISelect
                value={form.language}
                onChange={value => setForm(prev => ({ ...prev, language: value }))}
                options={[
                  { value: 'uk', label: 'uk' },
                  { value: 'en', label: 'en' },
                  { value: 'de', label: 'de' },
                ]}
              />
            </div>
            <div>
              <div className="mb-1 text-sm opacity-70">Country</div>
              <UIInput
                placeholder="CH"
                value={form.country}
                onChange={e => setForm(prev => ({ ...prev, country: e.target.value.toUpperCase() }))}
              />
            </div>
            <div>
              <div className="mb-1 text-sm opacity-70">Imported status</div>
              <UISelect
                value={form.status}
                onChange={value => setForm(prev => ({ ...prev, status: value as 'draft' | 'published' }))}
                options={[
                  { value: 'published', label: 'published' },
                  { value: 'draft', label: 'draft' },
                ]}
              />
            </div>
            <div>
              <div className="mb-1 text-sm opacity-70">Enabled</div>
              <label className="inline-flex h-[42px] w-full items-center gap-2 rounded-xl border border-white/10 px-3">
                <input
                  type="checkbox"
                  checked={form.enabled}
                  onChange={e => setForm(prev => ({ ...prev, enabled: e.target.checked }))}
                />
                <span className="text-sm opacity-80">Include in weekly scheduler</span>
              </label>
            </div>
            <div>
              <div className="mb-1 text-sm opacity-70">Max results</div>
              <UIInput
                type="number"
                value={form.max_results as any}
                onChange={e => setForm(prev => ({ ...prev, max_results: Number(e.target.value || 8) }))}
              />
            </div>
            <div>
              <div className="mb-1 text-sm opacity-70">Freshness window (days)</div>
              <UIInput
                type="number"
                value={form.freshness_days as any}
                onChange={e => setForm(prev => ({ ...prev, freshness_days: Number(e.target.value || 7) }))}
              />
            </div>
          </div>
          <div className="text-right">
            <Button onClick={submit} disabled={loading || !form.query.trim()}>
              {loading ? 'Saving…' : editing ? 'Save Changes' : 'Create Query'}
            </Button>
          </div>
        </div>
      </Dialog>
    </div>
  )
}

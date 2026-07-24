"use client"

import { useEffect, useState } from "react"

type Moment = {
  id: string
  key: string
  title: string
  description_md: string
  starts_at: string
  ends_at: string
  recurrence: string
  audience_filters: Record<string, unknown>
  cta_kind: string
  cta_payload: Record<string, unknown>
  priority: number
  is_active: boolean
  created_at: string
  updated_at: string
}

type Draft = {
  key: string
  title: string
  description_md: string
  starts_at: string
  ends_at: string
  recurrence: string
  cantons: string
  permits: string
  min_tenure_months: string
  has_children: string
  life_events: string
  cta_kind: string
  cta_payload: string
  priority: string
  is_active: boolean
}

const emptyDraft: Draft = {
  key: "",
  title: "",
  description_md: "",
  starts_at: "",
  ends_at: "",
  recurrence: "yearly",
  cantons: "",
  permits: "",
  min_tenure_months: "",
  has_children: "any",
  life_events: "",
  cta_kind: "link",
  cta_payload: "{}",
  priority: "0",
  is_active: true,
}

export default function MomentsManager() {
  const [items, setItems] = useState<Moment[]>([])
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [draft, setDraft] = useState<Draft>(emptyDraft)
  const [error, setError] = useState<string | null>(null)

  async function load() {
    setLoading(true)
    try {
      const res = await fetch("/api/admin/moments", { cache: "no-store" })
      const data = await res.json().catch(() => [])
      setItems(Array.isArray(data) ? data : [])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
  }, [])

  function buildPayload(): Record<string, unknown> | null {
    try {
      const ctaPayload = draft.cta_payload.trim().length ? JSON.parse(draft.cta_payload) : {}
      const filters: Record<string, unknown> = {}
      const cantons = draft.cantons.split(",").map(s => s.trim()).filter(Boolean)
      if (cantons.length) filters.cantons = cantons
      const permits = draft.permits.split(",").map(s => s.trim().toUpperCase()).filter(Boolean)
      if (permits.length) filters.permits = permits
      if (draft.min_tenure_months) filters.min_tenure_months = Number(draft.min_tenure_months) || 0
      if (draft.has_children === "yes") filters.has_children = true
      if (draft.has_children === "no") filters.has_children = false
      const events = draft.life_events.split(",").map(s => s.trim()).filter(Boolean)
      if (events.length) filters.life_events = events

      return {
        key: draft.key.trim(),
        title: draft.title.trim(),
        description_md: draft.description_md,
        starts_at: new Date(draft.starts_at).toISOString(),
        ends_at: new Date(draft.ends_at).toISOString(),
        recurrence: draft.recurrence,
        audience_filters: filters,
        cta_kind: draft.cta_kind,
        cta_payload: ctaPayload,
        priority: Number(draft.priority) || 0,
        is_active: draft.is_active,
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Invalid payload")
      return null
    }
  }

  async function create() {
    setError(null)
    const payload = buildPayload()
    if (!payload) return
    setBusyId("__new__")
    try {
      const res = await fetch("/api/admin/moments", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      })
      if (!res.ok) {
        setError(await res.text())
        return
      }
      setDraft(emptyDraft)
      await load()
    } finally {
      setBusyId(null)
    }
  }

  async function toggleActive(item: Moment) {
    setBusyId(item.id)
    try {
      await fetch(`/api/admin/moments/${item.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ is_active: !item.is_active }),
      })
      await load()
    } finally {
      setBusyId(null)
    }
  }

  async function remove(item: Moment) {
    if (!window.confirm(`Delete moment "${item.title}"?`)) return
    setBusyId(item.id)
    try {
      await fetch(`/api/admin/moments/${item.id}`, { method: "DELETE" })
      await load()
    } finally {
      setBusyId(null)
    }
  }

  return (
    <div className="space-y-6">
      <div className="glass space-y-3 rounded-2xl p-5">
        <h3 className="text-lg font-semibold">New moment</h3>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
          <Field label="Key (unique)" value={draft.key} onChange={v => setDraft({ ...draft, key: v })} />
          <Field label="Title" value={draft.title} onChange={v => setDraft({ ...draft, title: v })} />
          <Field label="Starts at (ISO)" value={draft.starts_at} placeholder="2026-09-25T00:00:00Z" onChange={v => setDraft({ ...draft, starts_at: v })} />
          <Field label="Ends at (ISO)" value={draft.ends_at} placeholder="2026-11-30T23:59:59Z" onChange={v => setDraft({ ...draft, ends_at: v })} />
          <Field label="Cantons (comma)" value={draft.cantons} onChange={v => setDraft({ ...draft, cantons: v })} />
          <Field label="Permits (comma)" value={draft.permits} onChange={v => setDraft({ ...draft, permits: v })} />
          <Field label="Min tenure (months)" value={draft.min_tenure_months} onChange={v => setDraft({ ...draft, min_tenure_months: v })} />
          <Field label="Life events (comma)" value={draft.life_events} onChange={v => setDraft({ ...draft, life_events: v })} />
          <Select label="Has children" value={draft.has_children} onChange={v => setDraft({ ...draft, has_children: v })}
            options={[["any", "any"], ["yes", "yes"], ["no", "no"]]} />
          <Select label="Recurrence" value={draft.recurrence} onChange={v => setDraft({ ...draft, recurrence: v })}
            options={[["yearly", "yearly"], ["once", "once"], ["quarterly", "quarterly"]]} />
          <Select label="CTA kind" value={draft.cta_kind} onChange={v => setDraft({ ...draft, cta_kind: v })}
            options={[["link", "link"], ["checklist", "checklist"], ["calculator", "calculator"], ["deeplink", "deeplink"]]} />
          <Field label="Priority" value={draft.priority} onChange={v => setDraft({ ...draft, priority: v })} />
        </div>
        <Field label="CTA payload (JSON)" value={draft.cta_payload} onChange={v => setDraft({ ...draft, cta_payload: v })} />
        <Field label="Description (markdown)" value={draft.description_md} onChange={v => setDraft({ ...draft, description_md: v })} multiline />
        {error && <div className="rounded-xl bg-red-500/15 p-3 text-sm text-red-200">{error}</div>}
        <div className="flex gap-2">
          <button
            disabled={busyId === "__new__"}
            onClick={create}
            className="rounded-lg bg-emerald-500/20 px-4 py-2 text-sm text-emerald-200 disabled:opacity-50"
          >
            {busyId === "__new__" ? "..." : "Create moment"}
          </button>
          <button
            type="button"
            onClick={() => setDraft(emptyDraft)}
            className="rounded-lg bg-white/10 px-4 py-2 text-sm"
          >
            Reset
          </button>
        </div>
      </div>

      {loading ? (
        <div className="glass rounded-xl p-6">Loading moments…</div>
      ) : items.length === 0 ? (
        <div className="glass rounded-xl p-6">No moments yet. Create one above or wait for default seed.</div>
      ) : (
        <div className="space-y-3">
          {items.map(item => (
            <div key={item.id} className="glass space-y-3 rounded-2xl p-4">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="rounded-full bg-white/10 px-2 py-1 text-xs">{item.key}</span>
                    {item.is_active ? (
                      <span className="rounded-full bg-emerald-500/20 px-2 py-1 text-xs text-emerald-200">active</span>
                    ) : (
                      <span className="rounded-full bg-white/10 px-2 py-1 text-xs">inactive</span>
                    )}
                    <span className="rounded-full bg-sky-500/20 px-2 py-1 text-xs text-sky-200">prio {item.priority}</span>
                  </div>
                  <div className="mt-1 text-base font-semibold">{item.title}</div>
                  <div className="text-xs opacity-70">
                    {new Date(item.starts_at).toLocaleDateString()} → {new Date(item.ends_at).toLocaleDateString()} • {item.recurrence}
                  </div>
                </div>
                <div className="flex flex-wrap gap-2">
                  <button
                    disabled={busyId === item.id}
                    onClick={() => toggleActive(item)}
                    className="rounded-lg bg-white/10 px-3 py-2 text-sm disabled:opacity-50"
                  >
                    {item.is_active ? "Deactivate" : "Activate"}
                  </button>
                  <button
                    disabled={busyId === item.id}
                    onClick={() => remove(item)}
                    className="rounded-lg bg-red-500/20 px-3 py-2 text-sm text-red-200 disabled:opacity-50"
                  >
                    Delete
                  </button>
                </div>
              </div>
              <pre className="overflow-x-auto rounded-xl bg-black/30 p-3 text-xs opacity-80">
{JSON.stringify({ filters: item.audience_filters, cta_kind: item.cta_kind, cta_payload: item.cta_payload }, null, 2)}
              </pre>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

function Field({ label, value, onChange, placeholder, multiline = false }: {
  label: string
  value: string
  onChange: (v: string) => void
  placeholder?: string
  multiline?: boolean
}) {
  return (
    <label className="flex flex-col gap-1 text-sm">
      <span className="opacity-70">{label}</span>
      {multiline ? (
        <textarea
          className="min-h-24 rounded-lg border border-white/10 bg-white/5 p-2 outline-none"
          value={value}
          placeholder={placeholder}
          onChange={e => onChange(e.target.value)}
        />
      ) : (
        <input
          className="rounded-lg border border-white/10 bg-white/5 p-2 outline-none"
          value={value}
          placeholder={placeholder}
          onChange={e => onChange(e.target.value)}
        />
      )}
    </label>
  )
}

function Select({ label, value, onChange, options }: {
  label: string
  value: string
  onChange: (v: string) => void
  options: [string, string][]
}) {
  return (
    <label className="flex flex-col gap-1 text-sm">
      <span className="opacity-70">{label}</span>
      <select
        className="rounded-lg border border-white/10 bg-white/5 p-2 outline-none"
        value={value}
        onChange={e => onChange(e.target.value)}
      >
        {options.map(([v, l]) => (
          <option key={v} value={v} className="bg-slate-900">{l}</option>
        ))}
      </select>
    </label>
  )
}

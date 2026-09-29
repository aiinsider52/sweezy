"use client"

import { useEffect, useState } from "react"

type Suggestion = {
  id: string
  name: string
  category: string
  street: string
  postal_code: string
  city: string
  country_code: string
  subdivision_code?: string | null
  website?: string | null
  phone?: string | null
  note: string
  status: "pending" | "approved" | "rejected"
  rejection_reason?: string | null
  created_at: string
}

type Draft = { latitude: string; longitude: string; subdivision: string }

export default function PlaceSuggestionList() {
  const [items, setItems] = useState<Suggestion[]>([])
  const [status, setStatus] = useState("pending")
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")
  const [busy, setBusy] = useState("")
  const [drafts, setDrafts] = useState<Record<string, Draft>>({})

  async function load(nextStatus: string) {
    setLoading(true)
    try {
      const qs = nextStatus === "all" ? "status=" : `status=${nextStatus}`
      const res = await fetch(`/api/admin/place-suggestions?${qs}`, { cache: "no-store" })
      if (!res.ok) throw new Error(`Could not load suggestions (${res.status})`)
      const data = await res.json()
      setItems(Array.isArray(data) ? data : [])
      setError("")
    } catch (value) {
      setError(value instanceof Error ? value.message : "Could not load suggestions")
    } finally { setLoading(false) }
  }

  useEffect(() => { load(status) }, [status])

  function draftFor(item: Suggestion): Draft {
    return drafts[item.id] ?? { latitude: "", longitude: "", subdivision: item.subdivision_code ?? "" }
  }

  function updateDraft(item: Suggestion, patch: Partial<Draft>) {
    setDrafts(current => ({ ...current, [item.id]: { ...draftFor(item), ...patch } }))
  }

  async function geocode(item: Suggestion) {
    setBusy(item.id)
    try {
      const query = `${item.street}, ${item.postal_code} ${item.city}`
      const res = await fetch(`/api/admin/geocode?country=${item.country_code}&q=${encodeURIComponent(query)}`, { cache: "no-store" })
      if (!res.ok) throw new Error("Address not found — set coordinates manually")
      const hit = await res.json()
      updateDraft(item, { latitude: Number(hit.latitude).toFixed(6), longitude: Number(hit.longitude).toFixed(6) })
      setError("")
    } catch (value) {
      setError(value instanceof Error ? value.message : "Geocoding failed")
    } finally { setBusy("") }
  }

  async function moderate(item: Suggestion, decision: "approved" | "rejected") {
    const draft = draftFor(item)
    const body: Record<string, unknown> = { status: decision }
    if (decision === "rejected") {
      const reason = window.prompt("Reason shown to the user:")
      if (!reason?.trim()) return
      body.rejection_reason = reason.trim()
    } else {
      const latitude = Number(draft.latitude)
      const longitude = Number(draft.longitude)
      if (!draft.latitude || !draft.longitude || Number.isNaN(latitude) || Number.isNaN(longitude)) {
        setError("Set coordinates before approving")
        return
      }
      Object.assign(body, { latitude, longitude, subdivision_code: draft.subdivision || null })
    }
    setBusy(item.id)
    try {
      const res = await fetch(`/api/admin/place-suggestions/${item.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      })
      if (!res.ok) throw new Error((await res.json().catch(() => null))?.detail || `Moderation failed (${res.status})`)
      await load(status)
    } catch (value) {
      setError(value instanceof Error ? value.message : "Moderation failed")
    } finally { setBusy("") }
  }

  return <div className="space-y-5">
    <div className="flex flex-wrap gap-2">
      {["pending", "approved", "rejected", "all"].map(value => <button key={value} onClick={() => setStatus(value)} className={`rounded-lg px-3 py-2 text-sm ${status === value ? "bg-white/20" : "bg-white/5"}`}>
        {value[0].toUpperCase() + value.slice(1)}
      </button>)}
    </div>
    {error && <div className="rounded-xl border border-red-500/40 bg-red-500/10 p-3 text-sm text-red-200">{error}</div>}
    {loading ? <p className="text-white/60">Loading…</p> : items.length === 0 ? <p className="rounded-xl bg-white/5 p-8 text-center text-white/50">No suggestions in this queue.</p> :
      <div className="grid gap-4 xl:grid-cols-2">{items.map(item => {
        const draft = draftFor(item)
        const address = `${item.street}, ${item.postal_code} ${item.city}`
        return <article key={item.id} className="rounded-2xl border border-white/10 bg-white/[0.04] p-5">
          <div className="flex items-start justify-between gap-3">
            <div>
              <div className="text-xs font-semibold uppercase tracking-widest text-lime-300">{item.category.replace("_", " ")} · {item.country_code}{item.subdivision_code ? `-${item.subdivision_code}` : ""}</div>
              <h3 className="mt-1 text-xl font-semibold">{item.name}</h3>
              <a className="text-sm text-white/55 underline decoration-white/20" target="_blank" rel="noreferrer" href={`https://www.openstreetmap.org/search?query=${encodeURIComponent(address)}`}>{address}</a>
            </div>
            <span className="rounded-full bg-white/10 px-2.5 py-1 text-xs">{item.status}</span>
          </div>
          <p className="mt-4 whitespace-pre-wrap text-sm leading-6 text-white/75">{item.note}</p>
          <div className="mt-3 flex flex-wrap gap-3 text-sm">
            {item.website && <a className="text-lime-300 underline" target="_blank" rel="noreferrer" href={item.website}>{item.website}</a>}
            {item.phone && <span className="text-white/60">{item.phone}</span>}
            <span className="text-white/35">{new Date(item.created_at).toLocaleString()}</span>
          </div>
          {item.rejection_reason && <p className="mt-3 text-sm text-amber-300">Reason: {item.rejection_reason}</p>}
          {item.status === "pending" && <>
            <div className="mt-5 grid grid-cols-[1fr_1fr_80px_auto] gap-2">
              <input value={draft.latitude} onChange={event => updateDraft(item, { latitude: event.target.value })} placeholder="Latitude" className="rounded-xl bg-black/30 px-3 py-2 text-sm outline-none ring-1 ring-white/10" />
              <input value={draft.longitude} onChange={event => updateDraft(item, { longitude: event.target.value })} placeholder="Longitude" className="rounded-xl bg-black/30 px-3 py-2 text-sm outline-none ring-1 ring-white/10" />
              <input value={draft.subdivision} onChange={event => updateDraft(item, { subdivision: event.target.value.toUpperCase() })} placeholder="ZH" className="rounded-xl bg-black/30 px-3 py-2 text-sm outline-none ring-1 ring-white/10" />
              <button disabled={busy === item.id} onClick={() => geocode(item)} className="rounded-xl bg-white/10 px-3 py-2 text-sm disabled:opacity-40">Find</button>
            </div>
            <div className="mt-3 flex gap-2">
              <button disabled={busy === item.id} onClick={() => moderate(item, "approved")} className="flex-1 rounded-xl bg-lime-400 px-4 py-3 font-semibold text-black disabled:opacity-40">Approve</button>
              <button disabled={busy === item.id} onClick={() => moderate(item, "rejected")} className="flex-1 rounded-xl bg-red-500/15 px-4 py-3 font-semibold text-red-200 disabled:opacity-40">Reject</button>
            </div>
          </>}
        </article>
      })}</div>}
  </div>
}

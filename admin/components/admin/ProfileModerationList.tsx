"use client"

import { useEffect, useMemo, useState } from "react"

type Profile = {
  kind: "social" | "professional"
  user_id: string
  display_name: string
  canton: string
  city: string
  bio: string
  avatar_url?: string | null
  moderation_status: "pending" | "approved" | "rejected"
  moderation_reason?: string | null
  updated_at?: string | null
  details: Record<string, unknown>
}

export default function ProfileModerationList({ initialKind = "all" }: { initialKind?: "all" | "social" | "professional" }) {
  const [items, setItems] = useState<Profile[]>([])
  const [status, setStatus] = useState("pending")
  const [kind, setKind] = useState(initialKind)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")
  const [busy, setBusy] = useState("")

  async function load() {
    setLoading(true)
    try {
      const res = await fetch("/api/admin/profile-moderation", { cache: "no-store" })
      if (!res.ok) throw new Error(`Could not load profiles (${res.status})`)
      const data = await res.json()
      setItems(Array.isArray(data) ? data : [])
      setError("")
    } catch (value) {
      setError(value instanceof Error ? value.message : "Could not load profiles")
    } finally { setLoading(false) }
  }

  useEffect(() => {
    load()
    const timer = window.setInterval(load, 30000)
    return () => window.clearInterval(timer)
  }, [])

  const filtered = useMemo(() => items.filter(item =>
    (status === "all" || item.moderation_status === status) && (kind === "all" || item.kind === kind)
  ), [items, status, kind])
  const pending = items.filter(item => item.moderation_status === "pending").length

  async function decide(item: Profile, decision: "approve" | "reject") {
    const reason = decision === "reject"
      ? window.prompt("Reason shown to user:")
      : window.prompt("Internal note (optional):")
    if (decision === "reject" && !reason?.trim()) return
    setBusy(`${item.kind}:${item.user_id}`)
    try {
      const res = await fetch(`/api/admin/profile-moderation/${item.kind}/${item.user_id}/${decision}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ reason: reason?.trim() || null }),
      })
      if (!res.ok) throw new Error((await res.json().catch(() => null))?.detail || `Moderation failed (${res.status})`)
      await load()
    } catch (value) {
      setError(value instanceof Error ? value.message : "Moderation failed")
    } finally { setBusy("") }
  }

  return <div className="space-y-5">
    <div className="flex flex-wrap gap-2">
      {["pending", "approved", "rejected", "all"].map(value => <button key={value} onClick={() => setStatus(value)} className={`rounded-lg px-3 py-2 text-sm ${status === value ? "bg-white/20" : "bg-white/5"}`}>
        {value[0].toUpperCase() + value.slice(1)}{value === "pending" && pending > 0 ? ` (${pending})` : ""}
      </button>)}
      <span className="w-px bg-white/10" />
      {(["all", "social", "professional"] as const).map(value => <button key={value} onClick={() => setKind(value)} className={`rounded-lg px-3 py-2 text-sm ${kind === value ? "bg-lime-400 text-black" : "bg-white/5"}`}>
        {value === "all" ? "All profiles" : value === "social" ? "Social Passport" : "Professional"}
      </button>)}
    </div>
    {error && <div className="rounded-xl border border-red-500/40 bg-red-500/10 p-3 text-sm text-red-200">{error}</div>}
    {loading ? <p className="text-white/60">Loading…</p> : filtered.length === 0 ? <p className="rounded-xl bg-white/5 p-8 text-center text-white/50">No profiles in this queue.</p> :
      <div className="grid gap-4 xl:grid-cols-2">{filtered.map(item => {
        const key = `${item.kind}:${item.user_id}`
        return <article key={key} className="rounded-2xl border border-white/10 bg-white/[0.04] p-5">
          <div className="flex items-start justify-between gap-3">
            <div><div className="text-xs font-semibold uppercase tracking-widest text-lime-300">{item.kind === "social" ? "Social Passport" : "Professional profile"}</div><h3 className="mt-1 text-xl font-semibold">{item.display_name}</h3><p className="text-sm text-white/50">{item.city} · {item.canton}</p></div>
            <span className="rounded-full bg-white/10 px-2.5 py-1 text-xs">{item.moderation_status}</span>
          </div>
          <p className="mt-4 whitespace-pre-wrap text-sm leading-6 text-white/75">{item.bio}</p>
          <pre className="mt-4 max-h-40 overflow-auto rounded-xl bg-black/25 p-3 text-xs text-white/55">{JSON.stringify(item.details, null, 2)}</pre>
          {item.moderation_reason && <p className="mt-3 text-sm text-amber-300">Reason: {item.moderation_reason}</p>}
          <div className="mt-5 flex gap-2"><button disabled={busy === key} onClick={() => decide(item, "approve")} className="flex-1 rounded-xl bg-lime-400 px-4 py-3 font-semibold text-black disabled:opacity-40">Approve</button><button disabled={busy === key} onClick={() => decide(item, "reject")} className="flex-1 rounded-xl bg-red-500/15 px-4 py-3 font-semibold text-red-200 disabled:opacity-40">Reject</button></div>
        </article>
      })}</div>}
  </div>
}

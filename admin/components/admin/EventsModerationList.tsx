"use client"

import { useEffect, useMemo, useState } from "react"

type EventItem = {
  id: string
  title: string
  description: string
  category: string
  canton: string
  city: string
  venue_name?: string | null
  address?: string | null
  starts_at?: string | null
  ends_at?: string | null
  is_free: boolean
  price_info?: string | null
  contact_type: string
  contact_value?: string | null
  organizer_name: string
  status: "pending" | "approved" | "rejected" | string
  rejection_reason?: string | null
  view_count: number
  created_at?: string | null
}

type StatusFilter = "pending" | "approved" | "rejected" | "all"

export default function EventsModerationList() {
  const [status, setStatus] = useState<StatusFilter>("all")
  const [items, setItems] = useState<EventItem[]>([])
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [search, setSearch] = useState("")

  async function load() {
    setLoading(true)
    try {
      const res = await fetch(`/api/admin/events`, { cache: "no-store" })
      const data = await res.json().catch(() => [])
      setItems(Array.isArray(data) ? data : [])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
  }, [])

  const counts = useMemo(() => ({
    total: items.length,
    pending: items.filter(i => i.status === "pending").length,
    approved: items.filter(i => i.status === "approved").length,
    rejected: items.filter(i => i.status === "rejected").length,
  }), [items])

  const filteredItems = useMemo(() => {
    const query = search.trim().toLowerCase()
    return items.filter(item => {
      const matchesStatus = status === "all" ? true : item.status === status
      const haystack = [
        item.title,
        item.description,
        item.organizer_name,
        item.category,
        item.canton,
        item.city,
        item.venue_name ?? "",
        item.address ?? "",
        item.contact_type,
        item.contact_value ?? "",
        item.price_info ?? "",
      ].join(" ").toLowerCase()
      return matchesStatus && (query.length === 0 || haystack.includes(query))
    })
  }, [items, search, status])

  async function approve(id: string) {
    setBusyId(id)
    try {
      await fetch(`/api/admin/events/${id}/approve`, { method: "PATCH" })
      await load()
    } finally {
      setBusyId(null)
    }
  }

  async function reject(id: string) {
    const reason = window.prompt("Reason for rejection:")
    if (!reason) return
    setBusyId(id)
    try {
      await fetch(`/api/admin/events/${id}/reject`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ reason }),
      })
      await load()
    } finally {
      setBusyId(null)
    }
  }

  async function remove(id: string, title: string) {
    const confirmed = window.confirm(`Delete event "${title}"? This cannot be undone.`)
    if (!confirmed) return
    setBusyId(id)
    try {
      await fetch(`/api/admin/events/${id}`, { method: "DELETE" })
      await load()
    } finally {
      setBusyId(null)
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
        <div className="flex flex-wrap items-center gap-2">
          {(["all", "pending", "approved", "rejected"] as StatusFilter[]).map(value => (
            <button
              key={value}
              onClick={() => setStatus(value)}
              className={`rounded-lg px-3 py-2 text-sm transition ${status === value ? "bg-white/20" : "bg-white/5 hover:bg-white/10"}`}
            >
              {value === "all" ? "All events" : value[0].toUpperCase() + value.slice(1)}
            </button>
          ))}
        </div>

        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search title, organizer, city, category..."
          className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-sm outline-none placeholder:text-white/40 md:max-w-sm"
        />
      </div>

      <div className="grid grid-cols-2 gap-3 md:grid-cols-5">
        <StatCard label="All" value={counts.total} />
        <StatCard label="Pending" value={counts.pending} />
        <StatCard label="Approved" value={counts.approved} />
        <StatCard label="Rejected" value={counts.rejected} />
        <StatCard label="Visible" value={filteredItems.length} />
      </div>

      {loading ? (
        <div className="glass rounded-xl p-6">Loading events...</div>
      ) : filteredItems.length === 0 ? (
        <div className="glass rounded-xl p-6">No events match this filter.</div>
      ) : (
        <div className="space-y-4">
          {filteredItems.map(item => (
            <div key={item.id} className="glass space-y-4 rounded-2xl p-5">
              <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                <div className="space-y-2">
                  <div className="flex flex-wrap items-center gap-2">
                    <h3 className="text-lg font-semibold">{item.title}</h3>
                    <span className="rounded-full bg-white/10 px-2 py-1 text-xs uppercase">{item.status}</span>
                    <span className="rounded-full bg-white/10 px-2 py-1 text-xs">{item.category}</span>
                  </div>
                  <div className="text-sm opacity-75">
                    {item.organizer_name} • {item.city}, {item.canton} • {item.starts_at ?? "n/a"}
                  </div>
                  <div className="whitespace-pre-wrap text-sm opacity-70">{item.description}</div>
                </div>

                <div className="flex flex-wrap gap-2">
                  <button
                    disabled={busyId === item.id || item.status === "approved"}
                    onClick={() => approve(item.id)}
                    className="rounded-lg bg-emerald-500/20 px-3 py-2 text-sm text-emerald-200 disabled:opacity-50"
                  >
                    {busyId === item.id ? "..." : "Approve"}
                  </button>
                  <button
                    disabled={busyId === item.id || item.status === "rejected"}
                    onClick={() => reject(item.id)}
                    className="rounded-lg bg-red-500/20 px-3 py-2 text-sm text-red-200 disabled:opacity-50"
                  >
                    Reject
                  </button>
                  <button
                    disabled={busyId === item.id}
                    onClick={() => remove(item.id, item.title)}
                    className="rounded-lg bg-white/10 px-3 py-2 text-sm text-white/85 disabled:opacity-50"
                  >
                    Delete
                  </button>
                </div>
              </div>

              <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
                <InfoBlock label="Venue" value={item.venue_name || item.address || "Not specified"} />
                <InfoBlock label="Contact" value={`${item.contact_type}: ${item.contact_value ?? "hidden"}`} />
                <InfoBlock label="Price" value={item.is_free ? "Free" : (item.price_info || "Not specified")} />
                <InfoBlock label="Views" value={String(item.view_count ?? 0)} />
              </div>

              {item.rejection_reason && (
                <div className="rounded-xl bg-red-500/10 p-3 text-sm text-red-200">
                  <div className="mb-1 text-xs uppercase tracking-wide opacity-70">Rejection reason</div>
                  <div className="whitespace-pre-wrap">{item.rejection_reason}</div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

function StatCard({ label, value }: { label: string; value: number }) {
  return (
    <div className="glass rounded-xl p-4">
      <div className="text-xs uppercase tracking-wide opacity-60">{label}</div>
      <div className="mt-1 text-2xl font-semibold">{value}</div>
    </div>
  )
}

function InfoBlock({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-white/5 p-3">
      <div className="text-xs uppercase tracking-wide opacity-60">{label}</div>
      <div className="mt-1 break-all text-sm opacity-85">{value}</div>
    </div>
  )
}

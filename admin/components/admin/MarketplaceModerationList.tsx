"use client"

import { useEffect, useMemo, useState } from "react"

type Listing = {
  id: string
  listing_type?: "service" | "item" | string
  title: string
  description: string
  category: string
  canton: string
  price_info?: string | null
  price_chf?: number | null
  is_free?: boolean
  condition?: string | null
  negotiable?: boolean
  contact_type: string
  contact_value?: string | null
  image_urls?: string[] | null
  author_id?: string | null
  author_name: string
  status: "pending" | "approved" | "rejected" | string
  rejection_reason?: string | null
  ai_score?: number | null
  ai_score_reason?: string | null
  is_verified?: boolean
  is_featured?: boolean
  trust_level?: "community" | "verified" | "partner" | string
  partner_label?: string | null
  moderation_notes?: string | null
  is_expert?: boolean
  expert_specialty?: string | null
  expert_languages?: string[] | null
  response_time_hours?: number | null
  expert_bio?: string | null
  view_count: number
  created_at?: string
}

type StatusFilter = "pending" | "approved" | "rejected" | "all"

type TypeFilter = "all" | "service" | "item"

export default function MarketplaceModerationList() {
  const [status, setStatus] = useState<StatusFilter>("all")
  const [typeFilter, setTypeFilter] = useState<TypeFilter>("all")
  const [items, setItems] = useState<Listing[]>([])
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [search, setSearch] = useState("")

  async function load() {
    setLoading(true)
    try {
      const res = await fetch(`/api/admin/marketplace`, { cache: "no-store" })
      const data = await res.json().catch(() => [])
      setItems(Array.isArray(data) ? data : [])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
    const interval = window.setInterval(load, 30000)
    return () => window.clearInterval(interval)
  }, [])

  const counts = useMemo(() => ({
    total: items.length,
    pending: items.filter(i => i.status === "pending").length,
    approved: items.filter(i => i.status === "approved").length,
    rejected: items.filter(i => i.status === "rejected").length,
    verified: items.filter(i => i.is_verified).length,
    featured: items.filter(i => i.is_featured).length,
  }), [items])

  const filteredItems = useMemo(() => {
    const query = search.trim().toLowerCase()
    return items.filter(item => {
      const matchesStatus = status === "all" ? true : item.status === status
      const itemType = item.listing_type || "service"
      const matchesType = typeFilter === "all" ? true : itemType === typeFilter
      if (!matchesType) return false
      const haystack = [
        item.title,
        item.description,
        item.author_name,
        item.author_id ?? "",
        item.category,
        item.canton,
        item.contact_type,
        item.contact_value ?? "",
        item.price_info ?? "",
      ].join(" ").toLowerCase()

      const matchesSearch = query.length === 0 || haystack.includes(query)
      return matchesStatus && matchesSearch
    })
  }, [items, search, status, typeFilter])

  async function approve(id: string) {
    const isVerified = window.confirm("Mark this listing as verified?")
    const isFeatured = window.confirm("Feature this as a partner listing?")
    const partnerLabel = isFeatured ? window.prompt("Partner label (optional):") : null
    const isExpert = window.confirm("Promote to verified expert profile (visible in /experts)?")
    let expertSpecialty: string | null = null
    let expertLanguages: string[] | null = null
    let responseTime: number | null = null
    let expertBio: string | null = null
    if (isExpert) {
      expertSpecialty = window.prompt("Expert specialty (tax / legal / insurance / relocation / career / family):", "tax")
      const langsRaw = window.prompt("Expert languages (comma, e.g. de,en,uk):", "de,en")
      expertLanguages = (langsRaw || "").split(",").map(s => s.trim().toLowerCase()).filter(Boolean)
      const rt = window.prompt("Typical response time in hours (optional):", "24")
      const parsed = rt ? Number(rt) : NaN
      responseTime = Number.isFinite(parsed) && parsed > 0 ? parsed : null
      expertBio = window.prompt("Expert short bio (optional):") || null
    }
    const moderationNotes = window.prompt("Moderation notes (optional):")
    setBusyId(id)
    try {
      await fetch(`/api/admin/marketplace/${id}/approve`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          is_verified: isVerified,
          is_featured: isFeatured,
          partner_label: partnerLabel || null,
          moderation_notes: moderationNotes || null,
          is_expert: isExpert,
          expert_specialty: expertSpecialty,
          expert_languages: expertLanguages,
          response_time_hours: responseTime,
          expert_bio: expertBio,
        }),
      })
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
      await fetch(`/api/admin/marketplace/${id}/reject`, {
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
    const confirmed = window.confirm(`Delete listing "${title}"? This cannot be undone.`)
    if (!confirmed) return

    setBusyId(id)
    try {
      await fetch(`/api/admin/marketplace/${id}`, { method: "DELETE" })
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
              className={`rounded-lg px-3 py-2 text-sm transition ${
                status === value ? "bg-white/20" : "bg-white/5 hover:bg-white/10"
              }`}
            >
              <span className="inline-flex items-center gap-2">
                {value === "all" ? "All listings" : value[0].toUpperCase() + value.slice(1)}
                {value === "pending" && counts.pending > 0 && (
                  <span className="inline-flex min-w-5 items-center justify-center rounded-full bg-red-500 px-1.5 py-0.5 text-[10px] font-semibold leading-none text-white">
                    {counts.pending}
                  </span>
                )}
              </span>
            </button>
          ))}
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {(["all", "service", "item"] as TypeFilter[]).map(value => (
            <button
              key={value}
              onClick={() => setTypeFilter(value)}
              className={`rounded-lg px-3 py-2 text-sm transition ${
                typeFilter === value ? "bg-white/20" : "bg-white/5 hover:bg-white/10"
              }`}
            >
              {value === "all" ? "All types" : value === "service" ? "Services" : "Items"}
            </button>
          ))}
        </div>

        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search title, author, category, canton..."
          className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-sm outline-none placeholder:text-white/40 md:max-w-sm"
        />
      </div>

      <div className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <StatCard label="All" value={counts.total} />
        <StatCard label="Pending" value={counts.pending} highlight={counts.pending > 0} />
        <StatCard label="Approved" value={counts.approved} />
        <StatCard label="Rejected" value={counts.rejected} />
        <StatCard label="Verified" value={counts.verified} />
        <StatCard label="Featured" value={counts.featured} />
      </div>

      {counts.pending > 0 && (
        <div className="rounded-2xl border border-red-400/20 bg-red-500/10 px-4 py-3 text-sm text-red-100">
          <span className="font-medium">{counts.pending}</span> listing(s) are waiting for approval.
        </div>
      )}

      {loading ? (
        <div className="glass rounded-xl p-6">Loading marketplace listings...</div>
      ) : filteredItems.length === 0 ? (
        <div className="glass rounded-xl p-6">No listings match this filter.</div>
      ) : (
        <div className="space-y-4">
          {filteredItems.map(item => {
            const score = item.ai_score ?? null
            const scoreTone =
              score == null ? "bg-white/10 text-white/70" :
              score > 6 ? "border border-emerald-400/30 bg-emerald-500/20 text-emerald-300" :
              score >= 3 ? "border border-orange-400/30 bg-orange-500/20 text-orange-300" :
              "border border-red-400/30 bg-red-500/20 text-red-300"

            return (
              <div key={item.id} className="glass space-y-4 rounded-2xl p-5">
                {item.image_urls && item.image_urls.length > 0 && (
                  <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-4">
                    {item.image_urls.slice(0, 4).map((rawUrl, index) => {
                      const src = resolveMediaUrl(rawUrl)
                      return (
                        <a
                          key={`${item.id}-${index}`}
                          href={src}
                          target="_blank"
                          rel="noreferrer"
                          className="group relative overflow-hidden rounded-2xl border border-white/10 bg-white/5"
                        >
                          <img
                            src={src}
                            alt={`${item.title} photo ${index + 1}`}
                            className="h-36 w-full object-cover transition duration-300 group-hover:scale-[1.03]"
                          />
                          <div className="pointer-events-none absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/70 to-transparent px-3 py-2 text-xs text-white/80">
                            Photo {index + 1}
                          </div>
                        </a>
                      )
                    })}
                  </div>
                )}

                <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                  <div className="space-y-2">
                    <div className="flex flex-wrap items-center gap-2">
                      <h3 className="text-lg font-semibold">{item.title}</h3>
                      <span className="rounded-full bg-white/10 px-2 py-1 text-xs uppercase">{item.status}</span>
                      {(item.listing_type || "service") === "item" && (
                        <span className="rounded-full border border-teal-400/30 bg-teal-500/20 px-2 py-1 text-xs font-medium text-teal-200">
                          Item{item.condition ? ` · ${item.condition}` : ""}
                        </span>
                      )}
                      {item.is_verified && (
                        <span className="rounded-full border border-sky-400/30 bg-sky-500/20 px-2 py-1 text-xs font-medium text-sky-200">
                          Verified
                        </span>
                      )}
                      {item.is_featured && (
                        <span className="rounded-full border border-amber-400/30 bg-amber-500/20 px-2 py-1 text-xs font-medium text-amber-200">
                          Featured partner
                        </span>
                      )}
                      {item.is_expert && (
                        <span className="rounded-full border border-purple-400/30 bg-purple-500/20 px-2 py-1 text-xs font-medium text-purple-200">
                          Expert{item.expert_specialty ? ` · ${item.expert_specialty}` : ""}
                        </span>
                      )}
                      <span className={`rounded-full px-2 py-1 text-xs font-medium ${scoreTone}`}>
                        AI score: {score ?? "n/a"}/10
                      </span>
                    </div>
                    <div className="text-sm opacity-75">
                      {item.author_name} {item.author_id ? `• user: ${item.author_id}` : "• guest listing"} • {item.category} • {item.canton}
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
                  <InfoBlock label="Contact" value={`${item.contact_type}: ${item.contact_value ?? "hidden"}`} />
                  <InfoBlock label="Price" value={formatPrice(item)} />
                  <InfoBlock label="Trust" value={item.partner_label || item.trust_level || "community"} />
                  <InfoBlock label="Views" value={String(item.view_count ?? 0)} />
                  <InfoBlock label="Created" value={formatCreatedAt(item.created_at)} />
                </div>

                {item.moderation_notes && (
                  <div className="rounded-xl bg-sky-500/10 p-3 text-sm text-sky-100">
                    <div className="mb-1 text-xs uppercase tracking-wide opacity-70">Moderation notes</div>
                    <div className="whitespace-pre-wrap">{item.moderation_notes}</div>
                  </div>
                )}

                {item.ai_score_reason && (
                  <div className="rounded-xl bg-white/5 p-3 text-sm">
                    <div className="mb-1 text-xs uppercase tracking-wide opacity-60">AI reasoning</div>
                    <div className="whitespace-pre-wrap opacity-80">{item.ai_score_reason}</div>
                  </div>
                )}

                {item.rejection_reason && (
                  <div className="rounded-xl bg-red-500/10 p-3 text-sm text-red-200">
                    <div className="mb-1 text-xs uppercase tracking-wide opacity-70">Rejection reason</div>
                    <div className="whitespace-pre-wrap">{item.rejection_reason}</div>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}

function StatCard({ label, value, highlight = false }: { label: string; value: number; highlight?: boolean }) {
  return (
    <div className={`glass rounded-xl p-4 ${highlight ? "border border-red-400/20 bg-red-500/10" : ""}`}>
      <div className="text-xs uppercase tracking-wide opacity-60">{label}</div>
      <div className="mt-1 text-2xl font-semibold">{value}</div>
    </div>
  )
}

function InfoBlock({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-white/5 p-3">
      <div className="text-xs uppercase tracking-wide opacity-60">{label}</div>
      <div className="mt-1 text-sm opacity-85 break-all">{value}</div>
    </div>
  )
}

function resolveMediaUrl(rawUrl: string) {
  if (/^https?:\/\//i.test(rawUrl)) return rawUrl
  const apiBase = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-9xyk.onrender.com/api/v1"
  const origin = apiBase.replace(/\/api\/v1\/?$/, "")
  return rawUrl.startsWith("/") ? `${origin}${rawUrl}` : `${origin}/${rawUrl}`
}

function formatPrice(item: Listing) {
  if ((item.listing_type || "service") === "item") {
    if (item.is_free) return "Free (give away)"
    if (item.price_chf != null) return `CHF ${item.price_chf}${item.negotiable ? " (negotiable)" : ""}`
    return "Not specified"
  }
  return item.price_info || "Not specified"
}

function formatCreatedAt(value?: string) {
  if (!value) return "n/a"
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  return date.toLocaleString()
}

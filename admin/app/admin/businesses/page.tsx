"use client"

import { useCallback, useEffect, useMemo, useState } from "react"
import { Bot, Building2, CalendarClock, CheckCircle2, RefreshCw, Search, ShieldCheck, Users } from "lucide-react"
import toast from "react-hot-toast"

type BusinessRow = {
  user_id: string
  owner_email: string
  display_name: string
  legal_name?: string | null
  description: string
  category: string
  canton: string
  city: string
  languages: string[]
  delivery_modes: string[]
  uid_number?: string | null
  website?: string | null
  status: "draft" | "pending" | "approved" | "rejected" | "suspended"
  rejection_reason?: string | null
  is_verified: boolean
  submitted_at?: string | null
  reviewed_at?: string | null
  subscription_status: string
  subscription_expire_at?: string | null
  services_count: number
  leads_count: number
  bookings_count: number
  clients_count: number
  documents_count: number
  team_members_count: number
  ai_enabled: boolean
  ai_auto_reply: boolean
}

const dateTime = (value?: string | null) => value
  ? new Intl.DateTimeFormat("de-CH", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value))
  : "—"

export default function BusinessesPage() {
  const [rows, setRows] = useState<BusinessRow[]>([])
  const [query, setQuery] = useState("")
  const [status, setStatus] = useState("all")
  const [loading, setLoading] = useState(false)
  const [selected, setSelected] = useState<BusinessRow | null>(null)
  const [comment, setComment] = useState("")
  const [saving, setSaving] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const response = await fetch("/api/admin/businesses", { cache: "no-store" })
      const body = await response.json().catch(() => [])
      if (!response.ok) throw new Error(body.detail || "Business profiles could not be loaded")
      setRows(Array.isArray(body) ? body : [])
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Business profiles could not be loaded")
    } finally { setLoading(false) }
  }, [])

  useEffect(() => { void load() }, [load])

  const filtered = useMemo(() => rows.filter(row => {
    const needle = query.trim().toLowerCase()
    return (status === "all" || row.status === status)
      && (!needle || `${row.display_name} ${row.owner_email} ${row.city} ${row.uid_number ?? ""}`.toLowerCase().includes(needle))
  }), [query, rows, status])

  async function review(decision: "approve" | "reject" | "suspend") {
    if (!selected || ((decision === "reject" || decision === "suspend") && comment.trim().length < 3)) return
    setSaving(true)
    try {
      const response = await fetch(`/api/admin/businesses/${selected.user_id}/review`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ decision, comment: comment.trim() || undefined }),
      })
      const body = await response.json().catch(() => ({}))
      if (!response.ok) throw new Error(body.detail || "Review failed")
      setRows(current => current.map(row => row.user_id === body.user_id ? body : row))
      setSelected(body)
      setComment("")
      toast.success(decision === "approve" ? "Business approved" : decision === "reject" ? "Changes requested" : "Business suspended")
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Review failed")
    } finally { setSaving(false) }
  }

  const pending = rows.filter(row => row.status === "pending").length
  const approved = rows.filter(row => row.status === "approved").length
  const activePlus = rows.filter(row => ["premium", "trial"].includes(row.subscription_status)).length

  return <section className="space-y-6 pb-12">
    <header className="relative overflow-hidden rounded-[28px] border border-lime-300/20 bg-[#0d140e] p-6 md:p-8">
      <div className="absolute -right-16 -top-16 h-64 w-64 rounded-full border border-lime-300/15" />
      <div className="relative flex flex-col justify-between gap-5 lg:flex-row lg:items-end">
        <div><div className="flex items-center gap-2 text-xs font-bold uppercase tracking-[.22em] text-lime-300"><Building2 size={16} /> Sweezy Pro</div><h1 className="mt-3 text-3xl font-black md:text-5xl">Business control</h1><p className="mt-3 max-w-2xl text-sm leading-6 text-white/55">Moderation, Plus entitlement, services, CRM activity and AI receptionist readiness.</p></div>
        <button onClick={() => void load()} disabled={loading} className="flex min-h-11 items-center justify-center gap-2 rounded-xl border border-white/10 bg-white/[.05] px-4 text-sm font-semibold"><RefreshCw size={16} className={loading ? "animate-spin" : ""} /> Refresh</button>
      </div>
    </header>

    <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
      <Metric icon={<CalendarClock />} label="Waiting review" value={pending} accent />
      <Metric icon={<ShieldCheck />} label="Approved" value={approved} />
      <Metric icon={<CheckCircle2 />} label="Active Plus" value={activePlus} />
      <Metric icon={<Users />} label="CRM leads" value={rows.reduce((sum, row) => sum + row.leads_count, 0)} />
    </div>

    <div className="grid gap-3 rounded-[22px] border border-white/10 bg-white/[.035] p-4 md:grid-cols-[1fr_190px]">
      <label className="relative"><span className="sr-only">Search businesses</span><Search size={17} className="absolute left-3 top-3 text-white/35" /><input value={query} onChange={event => setQuery(event.target.value)} placeholder="Business, owner, city or UID" className="h-11 w-full rounded-xl border border-white/10 bg-black/20 pl-10 pr-3 outline-none focus:border-lime-300/60" /></label>
      <select aria-label="Status" value={status} onChange={event => setStatus(event.target.value)} className="h-11 rounded-xl border border-white/10 bg-[#111511] px-3 capitalize"><option value="all">All statuses</option>{["pending", "approved", "draft", "rejected", "suspended"].map(value => <option key={value}>{value}</option>)}</select>
    </div>

    <div className="grid gap-4 xl:grid-cols-[minmax(0,1.4fr)_minmax(360px,.8fr)]">
      <div className="grid content-start gap-3 md:grid-cols-2">
        {filtered.map(row => <button key={row.user_id} onClick={() => { setSelected(row); setComment("") }} className={`rounded-[22px] border p-5 text-left transition hover:border-lime-300/40 ${selected?.user_id === row.user_id ? "border-lime-300 bg-lime-300/[.06]" : "border-white/10 bg-white/[.03]"}`}>
          <div className="flex items-start justify-between gap-3"><div className="min-w-0"><h2 className="truncate text-lg font-bold">{row.display_name}</h2><p className="truncate text-xs text-white/40">{row.owner_email}</p></div><StatusBadge status={row.status} /></div>
          <p className="mt-4 line-clamp-2 text-sm leading-6 text-white/55">{row.description}</p>
          <div className="mt-4 flex flex-wrap gap-2 text-[11px]"><Pill>{row.city} · {row.canton}</Pill><Pill>{row.services_count} services</Pill><Pill>{row.leads_count} leads</Pill><Pill accent>{row.subscription_status === "premium" ? "Plus" : row.subscription_status}</Pill></div>
        </button>)}
        {!filtered.length && <div className="col-span-full rounded-[22px] border border-dashed border-white/10 p-12 text-center text-sm text-white/40">No businesses match filters.</div>}
      </div>
      <aside className="xl:sticky xl:top-6 xl:self-start">
        {selected ? <ReviewPanel row={selected} comment={comment} setComment={setComment} saving={saving} review={review} /> : <div className="rounded-[24px] border border-white/10 bg-white/[.03] p-8 text-center"><Building2 className="mx-auto text-white/25" size={38} /><p className="mt-4 text-sm text-white/45">Select business to inspect profile and moderation state.</p></div>}
      </aside>
    </div>
  </section>
}

function ReviewPanel({ row, comment, setComment, saving, review }: { row: BusinessRow; comment: string; setComment: (value: string) => void; saving: boolean; review: (decision: "approve" | "reject" | "suspend") => Promise<void> }) {
  return <div className="space-y-5 rounded-[26px] border border-white/10 bg-[#101410] p-5 md:p-6">
    <div className="flex items-start justify-between gap-3"><div><p className="text-xs font-bold uppercase tracking-[.18em] text-lime-300">Moderation record</p><h2 className="mt-2 text-2xl font-black">{row.display_name}</h2></div><StatusBadge status={row.status} /></div>
    <dl className="grid grid-cols-2 gap-3 text-xs"><Fact label="Owner" value={row.owner_email} /><Fact label="Location" value={`${row.city} · ${row.canton}`} /><Fact label="Submitted" value={dateTime(row.submitted_at)} /><Fact label="Reviewed" value={dateTime(row.reviewed_at)} /><Fact label="Plus access" value={`${row.subscription_status} · ${dateTime(row.subscription_expire_at)}`} /><Fact label="UID" value={row.uid_number || "—"} /></dl>
    <div className="rounded-2xl border border-white/10 bg-black/20 p-4"><div className="flex items-center gap-2 font-semibold"><Bot size={17} className="text-lime-300" /> Product readiness</div><div className="mt-3 grid grid-cols-2 gap-2 text-xs text-white/55"><span>{row.services_count} services</span><span>{row.leads_count} CRM leads</span><span>{row.bookings_count} bookings</span><span>{row.clients_count} clients</span><span>{row.documents_count} documents</span><span>{row.team_members_count} team members</span><span className={row.ai_enabled ? "text-lime-300" : "text-white/35"}>AI {row.ai_enabled ? (row.ai_auto_reply ? "auto-reply" : "draft mode") : "off"}</span><span>{row.languages.join(", ") || "No languages"}</span><span>{row.delivery_modes.join(", ") || "No delivery mode"}</span></div></div>
    {row.rejection_reason && <div className="rounded-2xl border border-amber-300/20 bg-amber-300/[.06] p-4 text-sm text-amber-100/70">{row.rejection_reason}</div>}
    <label className="block text-sm"><span className="mb-2 block text-white/50">Moderator comment</span><textarea value={comment} onChange={event => setComment(event.target.value)} maxLength={2000} placeholder="Required for reject or suspend" className="min-h-24 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-lime-300/60" /></label>
    <div className="grid grid-cols-2 gap-2"><button disabled={saving} onClick={() => void review("reject")} className="min-h-11 rounded-xl border border-amber-300/30 text-sm font-semibold text-amber-200 disabled:opacity-40">Request changes</button><button disabled={saving} onClick={() => void review("suspend")} className="min-h-11 rounded-xl border border-red-300/30 text-sm font-semibold text-red-200 disabled:opacity-40">Suspend</button><button disabled={saving} onClick={() => void review("approve")} className="col-span-2 min-h-12 rounded-xl bg-lime-300 font-bold text-black disabled:opacity-40">{saving ? "Saving…" : "Approve business"}</button></div>
  </div>
}

function Metric({ icon, label, value, accent }: { icon: React.ReactNode; label: string; value: number; accent?: boolean }) { return <div className={`rounded-[20px] border p-4 ${accent ? "border-lime-300/30 bg-lime-300/[.08]" : "border-white/10 bg-white/[.035]"}`}><div className={accent ? "text-lime-300" : "text-white/35"}>{icon}</div><div className="mt-5 text-2xl font-black">{value}</div><div className="text-xs text-white/45">{label}</div></div> }
function StatusBadge({ status }: { status: string }) { const colors: Record<string, string> = { approved: "bg-lime-300/15 text-lime-300", pending: "bg-amber-300/15 text-amber-200", rejected: "bg-red-300/15 text-red-200", suspended: "bg-red-500/20 text-red-200", draft: "bg-white/[.07] text-white/45" }; return <span className={`rounded-full px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider ${colors[status] ?? colors.draft}`}>{status}</span> }
function Pill({ children, accent }: { children: React.ReactNode; accent?: boolean }) { return <span className={`rounded-full px-2.5 py-1 ${accent ? "bg-lime-300/15 text-lime-300" : "bg-white/[.06] text-white/50"}`}>{children}</span> }
function Fact({ label, value }: { label: string; value: string }) { return <div><dt className="text-white/35">{label}</dt><dd className="mt-1 break-words font-medium text-white/70">{value}</dd></div> }

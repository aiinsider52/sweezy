"use client"

import { useCallback, useEffect, useMemo, useState } from "react"
import { CalendarClock, CheckCircle2, CreditCard, RefreshCw, Search, ShieldCheck, Sparkles } from "lucide-react"
import toast from "react-hot-toast"
import { Dialog } from "@/components/ui/dialog"
import UIButton from "@/components/ui/button"
import UIInput from "@/components/ui/input"

type SubscriptionRow = {
  row_id: string
  user_id: string
  email: string
  status: "free" | "trial" | "premium"
  expire_at?: string | null
  subscription_id?: string | null
  provider: "apple" | "stripe" | "manual" | "none"
  provider_status: string
  plan?: "monthly" | "yearly" | null
  product_id?: string | null
  purchased_at?: string | null
  current_period_end?: string | null
  auto_renew_enabled?: boolean | null
  environment?: string | null
  revocation_date?: string | null
  last_verified_at?: string | null
  original_transaction_id?: string | null
  latest_transaction_id?: string | null
  stripe_customer_id?: string | null
  stripe_subscription_id?: string | null
  created_at: string
  updated_at: string
  editable: boolean
}

type EventRow = { id: string; user_id?: string | null; provider?: string; type: string; created_at: string }
type Analytics = {
  totals: { monthly: number; yearly: number; premium_users: number; trial_users: number; free_users: number }
  by_month: { month: string; monthly: number; yearly: number }[]
}

const dateTime = (value?: string | null) => value
  ? new Intl.DateTimeFormat("de-CH", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value))
  : "—"
const dateInput = (value?: string | null) => value ? new Date(value).toISOString().slice(0, 10) : ""

export default function SubscriptionsPage() {
  const [rows, setRows] = useState<SubscriptionRow[]>([])
  const [events, setEvents] = useState<EventRow[]>([])
  const [analytics, setAnalytics] = useState<Analytics | null>(null)
  const [months, setMonths] = useState(6)
  const [query, setQuery] = useState("")
  const [provider, setProvider] = useState("all")
  const [status, setStatus] = useState("all")
  const [editing, setEditing] = useState<SubscriptionRow | null>(null)
  const [loading, setLoading] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const [listRes, eventRes, analyticsRes] = await Promise.all([
        fetch("/api/admin/subscriptions", { cache: "no-store" }),
        fetch("/api/admin/subscriptions/events", { cache: "no-store" }),
        fetch(`/api/admin/subscriptions/analytics?months=${months}`, { cache: "no-store" }),
      ])
      if (!listRes.ok) throw new Error("Subscriptions could not be loaded")
      const [list, eventList, summary] = await Promise.all([
        listRes.json(),
        eventRes.ok ? eventRes.json() : [],
        analyticsRes.ok ? analyticsRes.json() : null,
      ])
      setRows(Array.isArray(list) ? list : [])
      setEvents(Array.isArray(eventList) ? eventList : [])
      setAnalytics(summary?.totals ? summary : null)
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Subscriptions could not be loaded")
    } finally {
      setLoading(false)
    }
  }, [months])

  useEffect(() => { void load() }, [load])

  const filtered = useMemo(() => rows.filter(row => {
    const needle = query.trim().toLowerCase()
    return (!needle || row.email.toLowerCase().includes(needle) || row.user_id.toLowerCase().includes(needle))
      && (provider === "all" || row.provider === provider)
      && (status === "all" || row.status === status)
  }), [provider, query, rows, status])

  const activeRows = Array.from(rows.reduce((byUser, row) => {
    if (row.provider === "none" || !["active", "trial"].includes(row.provider_status)) return byUser
    const current = byUser.get(row.user_id)
    const priority = { apple: 3, stripe: 2, manual: 1, none: 0 }
    if (!current || priority[row.provider] > priority[current.provider]) byUser.set(row.user_id, row)
    return byUser
  }, new Map<string, SubscriptionRow>()).values())
  const renewalCount = activeRows.filter(row => row.auto_renew_enabled).length
  const monthRevenue = activeRows.reduce((total, row) => total + (row.plan === "yearly" ? 59.9 / 12 : row.plan === "monthly" ? 4.95 : 0), 0)

  return (
    <section className="space-y-6 pb-12">
      <header className="relative overflow-hidden rounded-[28px] border border-lime-300/20 bg-[#101510] p-6 md:p-8">
        <div className="absolute right-[-4rem] top-[-5rem] h-56 w-56 rounded-full border border-lime-300/20" />
        <div className="absolute right-2 top-1 h-36 w-36 rounded-full border border-lime-300/10" />
        <div className="relative flex flex-col justify-between gap-6 lg:flex-row lg:items-end">
          <div className="max-w-2xl">
            <div className="mb-3 flex items-center gap-2 text-xs font-bold uppercase tracking-[.22em] text-lime-300">
              <Sparkles size={15} /> Sweezy Plus control
            </div>
            <h1 className="text-3xl font-black tracking-tight md:text-5xl">Subscriptions</h1>
            <p className="mt-3 max-w-xl text-sm leading-6 text-white/55">Purchase source, lifecycle dates, renewal state and manual access in one audit-ready view.</p>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            <label className="text-xs text-white/50" htmlFor="analytics-months">Period</label>
            <select id="analytics-months" className="rounded-xl border border-white/10 bg-black/30 px-3 py-2" value={months} onChange={event => setMonths(Number(event.target.value))}>
              <option value={3}>3 months</option><option value={6}>6 months</option><option value={12}>12 months</option>
            </select>
            <UIButton variant="default" className="border border-white/10 bg-white/[.06]" onClick={() => void load()} disabled={loading}>
              <RefreshCw size={16} className={loading ? "animate-spin" : ""} />
              <span className="ml-2">Refresh</span>
            </UIButton>
          </div>
        </div>
      </header>

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-5">
        <Metric icon={<ShieldCheck />} label="Plus users" value={analytics?.totals.premium_users ?? 0} accent />
        <Metric icon={<CalendarClock />} label="Trials" value={analytics?.totals.trial_users ?? 0} />
        <Metric icon={<RefreshCw />} label="Auto-renew" value={renewalCount} />
        <Metric icon={<CreditCard />} label="Monthly plans" value={analytics?.totals.monthly ?? 0} />
        <Metric icon={<Sparkles />} label="Est. MRR" value={`${monthRevenue.toFixed(2)} CHF`} wide />
      </div>

      <div className="rounded-[24px] border border-white/10 bg-white/[.035] p-4 md:p-5">
        <div className="grid gap-3 md:grid-cols-[minmax(0,1fr)_180px_180px]">
          <label className="relative"><span className="sr-only">Search subscriptions</span>
            <Search className="absolute left-3 top-3 text-white/35" size={17} />
            <input value={query} onChange={event => setQuery(event.target.value)} placeholder="Search email or user ID" className="h-11 w-full rounded-xl border border-white/10 bg-black/20 pl-10 pr-3 outline-none focus:border-lime-300/60" />
          </label>
          <FilterSelect value={provider} onChange={setProvider} label="Provider" values={["all", "apple", "manual", "stripe", "none"]} />
          <FilterSelect value={status} onChange={setStatus} label="Status" values={["all", "premium", "trial", "free"]} />
        </div>
      </div>

      <div className="hidden overflow-hidden rounded-[24px] border border-white/10 bg-black/20 lg:block">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-white/10 text-[11px] uppercase tracking-[.12em] text-white/40">
            <tr><th className="p-4">Customer</th><th className="p-4">Plan</th><th className="p-4">Purchased</th><th className="p-4">Valid until</th><th className="p-4">Renewal</th><th className="p-4">State</th><th className="p-4 text-right">Manage</th></tr>
          </thead>
          <tbody>{filtered.map(row => <DesktopRow key={row.row_id} row={row} edit={() => setEditing(row)} />)}</tbody>
        </table>
        {!filtered.length && <Empty />}
      </div>

      <div className="grid gap-3 lg:hidden">
        {filtered.map(row => <MobileCard key={row.row_id} row={row} edit={() => setEditing(row)} />)}
        {!filtered.length && <Empty />}
      </div>

      <section className="rounded-[24px] border border-white/10 bg-white/[.03] p-5">
        <div className="mb-4 flex items-center justify-between"><div><h2 className="font-bold">Subscription timeline</h2><p className="text-xs text-white/45">Apple, Stripe and administrator events</p></div><span className="rounded-full bg-white/[.06] px-3 py-1 text-xs text-white/50">{events.length} events</span></div>
        <div className="max-h-80 space-y-1 overflow-auto">
          {events.map(event => <div key={event.id} className="grid gap-1 border-l border-white/10 py-2 pl-4 text-xs md:grid-cols-[100px_1fr_auto]"><ProviderBadge provider={event.provider ?? "unknown"} /><span className="text-white/75">{event.type}</span><time className="text-white/35">{dateTime(event.created_at)}</time></div>)}
          {!events.length && <p className="py-8 text-center text-sm text-white/40">No subscription events yet.</p>}
        </div>
      </section>

      <Dialog open={Boolean(editing)} onClose={() => setEditing(null)} size="lg" contentClassName="rounded-[28px]">
        {editing && <SubscriptionEditor row={editing} onClose={() => setEditing(null)} onSaved={load} />}
      </Dialog>
    </section>
  )
}

function SubscriptionEditor({ row, onClose, onSaved }: { row: SubscriptionRow; onClose: () => void; onSaved: () => Promise<void> }) {
  const [status, setStatus] = useState<"free" | "trial" | "premium">(row.status)
  const [plan, setPlan] = useState<"monthly" | "yearly">(row.plan ?? "monthly")
  const [purchasedAt, setPurchasedAt] = useState(dateInput(row.purchased_at))
  const [expireAt, setExpireAt] = useState(dateInput(row.current_period_end ?? row.expire_at))
  const [reason, setReason] = useState("")
  const [saving, setSaving] = useState(false)

  async function save() {
    setSaving(true)
    try {
      const response = await fetch(`/api/admin/users/${row.user_id}/subscription`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          status,
          plan: status === "premium" ? plan : undefined,
          purchased_at: purchasedAt ? new Date(`${purchasedAt}T00:00:00Z`).toISOString() : undefined,
          expire_at: status !== "free" && expireAt ? new Date(`${expireAt}T23:59:59Z`).toISOString() : undefined,
          reason,
        }),
      })
      const body = await response.json().catch(() => ({}))
      if (!response.ok) throw new Error(body.detail?.[0]?.msg ?? body.detail ?? "Update failed")
      toast.success("Subscription updated")
      await onSaved()
      onClose()
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Update failed")
    } finally { setSaving(false) }
  }

  return <div className="space-y-6">
    <div><div className="text-xs font-bold uppercase tracking-[.18em] text-lime-300">Manual entitlement</div><h2 className="mt-2 text-2xl font-black">Manage Plus access</h2><p className="mt-1 break-all text-sm text-white/45">{row.email}</p></div>
    {row.provider !== "manual" && row.provider !== "none" && <div className="rounded-2xl border border-amber-300/20 bg-amber-300/[.06] p-4 text-sm text-amber-100/75">Apple/Stripe record remains immutable. Change creates separate manual entitlement; verified transaction history stays intact. Free removes manual access only — App Store or Stripe access remains active until provider expiry.</div>}
    <div className="grid grid-cols-3 gap-2">{(["free", "trial", "premium"] as const).map(value => <button key={value} onClick={() => setStatus(value)} className={`min-h-11 rounded-xl border px-3 py-2 capitalize ${status === value ? "border-lime-300 bg-lime-300 text-black" : "border-white/10 bg-white/[.04]"}`}>{value === "premium" ? "Plus" : value}</button>)}</div>
    {status === "premium" && <label className="block text-sm"><span className="mb-2 block text-white/55">Plan</span><select value={plan} onChange={event => setPlan(event.target.value as "monthly" | "yearly")} className="h-11 w-full rounded-xl border border-white/10 bg-[#151915] px-3"><option value="monthly">Monthly · 4.95 CHF</option><option value="yearly">Yearly</option></select></label>}
    {status !== "free" && <div className="grid gap-4 sm:grid-cols-2"><label className="text-sm"><span className="mb-2 block text-white/55">Purchased / granted</span><UIInput type="date" value={purchasedAt} onChange={event => setPurchasedAt(event.target.value)} /></label><label className="text-sm"><span className="mb-2 block text-white/55">Valid until</span><UIInput type="date" value={expireAt} onChange={event => setExpireAt(event.target.value)} required /></label></div>}
    <label className="block text-sm"><span className="mb-2 block text-white/55">Reason for change</span><textarea value={reason} onChange={event => setReason(event.target.value)} minLength={3} maxLength={500} placeholder="Support case, promotion or correction…" className="min-h-24 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-lime-300/60" /></label>
    <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end"><UIButton variant="ghost" onClick={onClose}>Cancel</UIButton><button onClick={() => void save()} disabled={saving || reason.trim().length < 3 || (status !== "free" && !expireAt)} className="min-h-11 rounded-xl bg-lime-300 px-5 font-bold text-black disabled:cursor-not-allowed disabled:opacity-40">{saving ? "Saving…" : "Save changes"}</button></div>
  </div>
}

function DesktopRow({ row, edit }: { row: SubscriptionRow; edit: () => void }) {
  return <tr className="border-b border-white/[.06] transition hover:bg-white/[.025]"><td className="p-4"><div className="font-medium">{row.email}</div><div className="mt-1 max-w-48 truncate text-[10px] text-white/30">{row.user_id}</div></td><td className="p-4"><div className="flex items-center gap-2"><ProviderBadge provider={row.provider} /><span className="capitalize text-white/60">{row.plan ?? "—"}</span></div><div className="mt-1 max-w-40 truncate text-[10px] text-white/30">{row.product_id ?? row.subscription_id ?? "No provider record"}</div></td><td className="p-4 text-white/65">{dateTime(row.purchased_at)}</td><td className="p-4 text-white/65">{dateTime(row.current_period_end ?? row.expire_at)}</td><td className="p-4">{row.auto_renew_enabled == null ? <span className="text-white/30">—</span> : row.auto_renew_enabled ? <span className="text-lime-300">Enabled</span> : <span className="text-white/45">Off</span>}</td><td className="p-4"><StatusBadge status={row.status} providerStatus={row.provider_status} /></td><td className="p-4 text-right"><button onClick={edit} className="min-h-10 rounded-xl border border-white/10 px-3 text-xs font-semibold hover:border-lime-300/50 hover:text-lime-300">Manage</button></td></tr>
}

function MobileCard({ row, edit }: { row: SubscriptionRow; edit: () => void }) {
  return <article className="rounded-[22px] border border-white/10 bg-white/[.035] p-4"><div className="flex items-start justify-between gap-3"><div className="min-w-0"><p className="truncate font-semibold">{row.email}</p><div className="mt-2 flex gap-2"><ProviderBadge provider={row.provider} /><StatusBadge status={row.status} providerStatus={row.provider_status} /></div></div><button onClick={edit} className="min-h-10 shrink-0 rounded-xl border border-white/10 px-3 text-xs">Manage</button></div><dl className="mt-4 grid grid-cols-2 gap-3 text-xs"><DateFact label="Purchased" value={row.purchased_at} /><DateFact label="Valid until" value={row.current_period_end ?? row.expire_at} /><DateFact label="Plan" text={row.plan ?? "—"} /><DateFact label="Renewal" text={row.auto_renew_enabled == null ? "—" : row.auto_renew_enabled ? "Enabled" : "Off"} /></dl></article>
}

function Metric({ icon, label, value, accent, wide }: { icon: React.ReactNode; label: string; value: number | string; accent?: boolean; wide?: boolean }) { return <div className={`rounded-[20px] border p-4 ${wide ? "col-span-2 lg:col-span-1" : ""} ${accent ? "border-lime-300/30 bg-lime-300/[.08]" : "border-white/10 bg-white/[.035]"}`}><div className={accent ? "text-lime-300" : "text-white/35"}>{icon}</div><div className="mt-5 text-2xl font-black">{value}</div><div className="mt-1 text-xs text-white/45">{label}</div></div> }
function ProviderBadge({ provider }: { provider: string }) { const styles: Record<string, string> = { apple: "bg-white text-black", stripe: "bg-violet-400/15 text-violet-200", manual: "bg-amber-300/15 text-amber-200", none: "bg-white/[.06] text-white/35" }; return <span className={`inline-flex w-fit rounded-full px-2 py-1 text-[10px] font-bold uppercase tracking-wider ${styles[provider] ?? styles.none}`}>{provider}</span> }
function StatusBadge({ status, providerStatus }: { status: string; providerStatus: string }) { const active = status === "premium" || status === "trial"; return <span className={`inline-flex items-center gap-1 rounded-full px-2 py-1 text-[10px] font-bold uppercase tracking-wider ${active ? "bg-lime-300/15 text-lime-300" : "bg-white/[.06] text-white/40"}`}>{active && <CheckCircle2 size={11} />}{status === "premium" ? "Plus" : status} · {providerStatus}</span> }
function DateFact({ label, value, text }: { label: string; value?: string | null; text?: string }) { return <div><dt className="text-white/35">{label}</dt><dd className="mt-1 font-medium text-white/75">{text ?? dateTime(value)}</dd></div> }
function FilterSelect({ value, onChange, label, values }: { value: string; onChange: (value: string) => void; label: string; values: string[] }) { return <select aria-label={label} value={value} onChange={event => onChange(event.target.value)} className="h-11 w-full rounded-xl border border-white/10 bg-[#111511] px-3 capitalize outline-none focus:border-lime-300/60">{values.map(item => <option key={item} value={item}>{item === "all" ? `All ${label.toLowerCase()}s` : item}</option>)}</select> }
function Empty() { return <div className="p-12 text-center text-sm text-white/40">No subscriptions match selected filters.</div> }

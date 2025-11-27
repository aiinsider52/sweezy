"use client"
import { useEffect, useState } from "react"

type Row = {
  user_id: string
  email: string
  status: string
  expire_at?: string | null
  stripe_customer_id?: string | null
  stripe_subscription_id?: string | null
}

type EventRow = {
  id: string
  user_id?: string | null
  type: string
  created_at: string
}

export default function SubscriptionsPage() {
  const [rows, setRows] = useState<Row[]>([])
  const [events, setEvents] = useState<EventRow[]>([])
  const [analytics, setAnalytics] = useState<{ totals: { monthly: number, yearly: number, premium_users: number, trial_users: number, free_users: number }, by_month: { month: string, monthly: number, yearly: number }[] } | null>(null)
  const [months, setMonths] = useState<number>(6)
  const [funnel, setFunnel] = useState<{ by_type?: Record<string, number>, top_contexts?: { context: string, count: number }[] } | null>(null)
  const [loading, setLoading] = useState(false)

  async function load() {
    setLoading(true)
    try {
      const listRes = await fetch(`/api/admin/subscriptions`, { cache: "no-store" })
      const evsRes = await fetch(`/api/admin/subscriptions/events`, { cache: "no-store" })
      const anRes = await fetch(`/api/admin/subscriptions/analytics?months=${months}`, { cache: "no-store" })
      const funnelRes = await fetch(`/api/admin/paywall/funnel?days=30`, { cache: "no-store" })
      let list: any = []
      let evs: any = []
      let an: any = null
      let fun: any = null
      try { list = listRes.ok ? await listRes.json() : [] } catch { list = [] }
      try { evs = evsRes.ok ? await evsRes.json() : [] } catch { evs = [] }
      try { an = anRes.ok ? await anRes.json() : null } catch { an = null }
      try { fun = funnelRes.ok ? await funnelRes.json() : null } catch { fun = null }
      setRows(Array.isArray(list) ? list : [])
      setEvents(Array.isArray(evs) ? evs : [])
      setAnalytics(an && typeof an === 'object' && 'totals' in an ? an : null)
      setFunnel(fun && typeof fun === 'object' ? fun : null)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  async function setStatus(userId: string, status: string) {
    await fetch(`/api/admin/users/${userId}/subscription`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ status }) })
    load()
  }
  async function setPremium(userId: string, plan: "monthly" | "yearly") {
    await fetch(`/api/admin/users/${userId}/subscription`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ status: "premium", plan }) })
    load()
  }

  return (
    <div className="p-6 space-y-6">
      <div className="glass p-4 flex items-center justify-between">
        <div>
          <div className="text-lg font-semibold">Subscriptions</div>
          <div className="text-xs opacity-60">Stripe + manual overrides</div>
        </div>
        <div className="flex items-center gap-3">
          <label className="text-xs opacity-70">Months</label>
          <select className="glass px-2 py-1 rounded-md" value={months} onChange={e => setMonths(Number(e.target.value))}>
            <option value={3}>3</option>
            <option value={6}>6</option>
            <option value={12}>12</option>
          </select>
          <button className="glass px-3 py-2 rounded-md" onClick={load}>{loading ? "..." : "Refresh"}</button>
        </div>
      </div>
      
      {analytics && (
        <div className="glass p-4">
          <div className="text-sm font-medium mb-3">Analytics</div>
          <div className="flex gap-6 flex-wrap">
            <Stat label="Monthly" value={analytics.totals.monthly} />
            <Stat label="Yearly" value={analytics.totals.yearly} />
            <Stat label="Premium users" value={analytics.totals.premium_users} />
            <Stat label="Trial users" value={analytics.totals.trial_users} />
            <Stat label="Free users" value={analytics.totals.free_users} />
          </div>
          <div className="mt-4">
            <MiniBars data={analytics.by_month} />
            <div className="mt-4">
              <MiniStack totals={analytics.totals} />
            </div>
          </div>
        </div>
      )}
      
      {funnel && (
        <div className="glass p-4">
          <div className="text-sm font-medium mb-3">Paywall Funnel (30d)</div>
          <div className="flex gap-6 flex-wrap">
            <Stat label="Views" value={funnel.by_type?.view || 0} />
            <Stat label="CTA Click" value={funnel.by_type?.cta_click || 0} />
            <Stat label="Checkout" value={funnel.by_type?.purchase_start || 0} />
            <Stat label="Dismiss" value={funnel.by_type?.dismiss || 0} />
          </div>
          <div className="mt-3 text-xs opacity-70">
            Top contexts:
            <div className="flex gap-2 mt-2 flex-wrap">
              {(funnel.top_contexts || []).map((c) => (
                <span key={c.context} className="glass px-2 py-1 rounded-md">{c.context}: {c.count}</span>
              ))}
              {(funnel.top_contexts || []).length === 0 && <span>—</span>}
            </div>
          </div>
        </div>
      )}

      <div className="glass p-0 overflow-x-auto">
        <table className="min-w-full text-sm">
          <thead className="text-left opacity-70">
            <tr>
              <th className="py-2 px-4">Email</th>
              <th className="py-2 px-4">Status</th>
              <th className="py-2 px-4">Expire</th>
              <th className="py-2 px-4">Actions</th>
            </tr>
          </thead>
          <tbody>
            {rows.map(r => (
              <tr key={r.user_id} className="border-t border-white/10">
                <td className="py-2 px-4">{r.email}</td>
                <td className="py-2 px-4">{r.status}</td>
                <td className="py-2 px-4">{r.expire_at ? new Date(r.expire_at).toLocaleString() : "-"}</td>
                <td className="py-2 px-4">
                  <div className="flex gap-2">
                    <button className="glass px-2 py-1 rounded-md" onClick={() => setStatus(r.user_id, "free")}>Free</button>
                    <button className="glass px-2 py-1 rounded-md" onClick={() => setStatus(r.user_id, "trial")}>Trial</button>
                    <button className="glass px-2 py-1 rounded-md" onClick={() => setPremium(r.user_id, "monthly")}>Premium (Monthly)</button>
                    <button className="glass px-2 py-1 rounded-md" onClick={() => setPremium(r.user_id, "yearly")}>Premium (Yearly)</button>
                  </div>
                </td>
              </tr>
            ))}
            {rows.length === 0 && (
              <tr><td className="py-6 px-4 text-sm opacity-70">No users yet.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="glass p-4">
        <div className="text-sm font-medium mb-2">Recent Stripe events</div>
        <div className="flex flex-col gap-1 max-h-[320px] overflow-auto text-xs">
          {events.map(e => (
            <div key={e.id} className="glass p-2 rounded-md flex items-center justify-between">
              <span className="opacity-80">{e.type}</span>
              <span className="opacity-60">{new Date(e.created_at).toLocaleString()}</span>
            </div>
          ))}
          {events.length === 0 && <div className="opacity-60">No events</div>}
        </div>
      </div>
    </div>
  )
}

function Stat({ label, value }: { label: string, value: number }) {
  return (
    <div className="glass px-4 py-3 rounded-md">
      <div className="text-xs opacity-70">{label}</div>
      <div className="text-xl font-semibold">{value}</div>
    </div>
  )
}

function MiniBars({ data }: { data: { month: string, monthly: number, yearly: number }[] }) {
  const max = Math.max(1, ...data.map(d => d.monthly + d.yearly))
  return (
    <div className="flex items-end gap-6">
      {data.map(d => (
        <div key={d.month} className="flex flex-col items-center">
          <div className="flex items-end gap-2 h-24">
            <div className="w-3 bg-blue-400 rounded" style={{ height: `${(d.monthly / max) * 100}%` }} title={`Monthly ${d.monthly}`} />
            <div className="w-3 bg-cyan-400 rounded" style={{ height: `${(d.yearly / max) * 100}%` }} title={`Yearly ${d.yearly}`} />
          </div>
          <div className="text-[10px] opacity-70 mt-1">{d.month.slice(5)}</div>
        </div>
      ))}
    </div>
  )
}

function MiniStack({ totals }: { totals: { monthly: number, yearly: number, premium_users: number, trial_users: number, free_users: number } }) {
  const totalUsers = totals.premium_users + totals.trial_users + totals.free_users
  return (
    <div>
      <div className="text-xs opacity-70 mb-1">Users distribution</div>
      <div className="w-full h-3 rounded bg-white/10 relative overflow-hidden">
        <div className="h-3 bg-cyan-400" style={{ width: `${(totals.premium_users / Math.max(1, totalUsers)) * 100}%` }} title={`Premium ${totals.premium_users}`} />
        <div className="h-3 bg-yellow-400 absolute left-0" style={{ width: `${((totals.trial_users + totals.premium_users) / Math.max(1, totalUsers)) * 100}%`, opacity: 0.6 }} />
      </div>
      <div className="flex gap-4 mt-2 text-[10px] opacity-70">
        <span className="inline-flex items-center gap-1"><span className="w-2 h-2 inline-block bg-cyan-400 rounded"></span> Premium</span>
        <span className="inline-flex items-center gap-1"><span className="w-2 h-2 inline-block bg-yellow-400 rounded"></span> Trial</span>
        <span className="inline-flex items-center gap-1"><span className="w-2 h-2 inline-block bg-white/40 rounded"></span> Free</span>
      </div>
    </div>
  )
}



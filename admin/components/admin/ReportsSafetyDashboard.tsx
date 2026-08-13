"use client"

import { useCallback, useEffect, useState } from 'react'
import { AlertTriangle, Ban, CheckCircle2, Clock3, EyeOff, ShieldAlert, UserRoundX } from 'lucide-react'

type Action = { id: string; action: string; comment: string; moderator_id?: string; created_at?: string }
type Sanction = { id: string; action: string; status: string; strike_points: number; reason: string; expires_at?: string }
type Case = {
  id: string; source_type: string; source_id: string; subject_user_id?: string; subject_email?: string
  subject_safety_status?: string; subject_strikes: number; reporter_email?: string; reason: string; details?: string
  status: string; priority: string; context: Record<string, unknown>; moderator_comment?: string
  created_at?: string; actions: Action[]; sanctions: Sanction[]
}
type Stats = { open: number; reviewing: number; suspended: number; banned: number }

const actions = [
  { id: 'dismiss', label: 'Dismiss', icon: CheckCircle2 },
  { id: 'warn', label: 'Warn', icon: AlertTriangle },
  { id: 'hide', label: 'Hide', icon: EyeOff },
  { id: 'suspend', label: 'Suspend', icon: Clock3 },
  { id: 'ban', label: 'Ban', icon: Ban },
] as const

const profileActions = [
  { id: 'approve', label: 'Approve', icon: CheckCircle2 },
  { id: 'reject', label: 'Reject', icon: EyeOff },
  { id: 'suspend', label: 'Suspend', icon: Clock3 },
  { id: 'ban', label: 'Ban', icon: Ban },
] as const

export default function ReportsSafetyDashboard() {
  const [cases, setCases] = useState<Case[]>([])
  const [stats, setStats] = useState<Stats>({ open: 0, reviewing: 0, suspended: 0, banned: 0 })
  const [status, setStatus] = useState('open')
  const [source, setSource] = useState('')
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<Case | null>(null)
  const [comment, setComment] = useState('')
  const [days, setDays] = useState(7)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    const params = new URLSearchParams()
    if (status) params.set('status', status)
    if (source) params.set('source_type', source)
    if (search.trim()) params.set('search', search.trim())
    const [queueRes, statsRes] = await Promise.all([fetch(`/api/admin/reports-safety?${params}`, { cache: 'no-store' }), fetch('/api/admin/reports-safety/stats', { cache: 'no-store' })])
    if (!queueRes.ok) throw new Error('Could not load moderation queue')
    const queue = await queueRes.json()
    setCases(Array.isArray(queue) ? queue : [])
    if (statsRes.ok) setStats(await statsRes.json())
  }, [search, source, status])

  useEffect(() => { load().catch(error => setError(error.message)) }, [load])

  async function beginReview(item: Case) {
    if (item.status !== 'open') { setSelected(item); return }
    const response = await fetch(`/api/admin/reports-safety/${item.id}`, { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ status: 'reviewing' }) })
    if (!response.ok) throw new Error('Could not assign case')
    setSelected(await response.json())
    await load()
  }

  async function decide(action: typeof actions[number]['id'] | typeof profileActions[number]['id']) {
    if (!selected || comment.trim().length < 3) { setError('Moderator comment required'); return }
    setBusy(true); setError('')
    try {
      const response = await fetch(`/api/admin/reports-safety/${selected.id}/decision`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action, comment: comment.trim(), suspension_days: action === 'suspend' ? days : null }) })
      if (!response.ok) throw new Error((await response.json().catch(() => ({}))).detail || 'Decision failed')
      setSelected(null); setComment(''); await load()
    } catch (error) { setError(error instanceof Error ? error.message : 'Decision failed') }
    finally { setBusy(false) }
  }

  const cards = [
    ['Open', stats.open, ShieldAlert], ['Reviewing', stats.reviewing, Clock3], ['Suspended', stats.suspended, UserRoundX], ['Banned', stats.banned, Ban],
  ] as const

  return <div className="space-y-6">
    <div><div className="text-xs font-semibold uppercase tracking-[.22em] text-lime-300">Trust operations</div><h1 className="mt-2 text-3xl font-semibold">Reports & Safety</h1><p className="mt-2 max-w-3xl text-sm text-white/55">Single queue for profiles, marketplace, events, chats, jobs and reviews. Every decision creates audit trail and user notification.</p></div>
    <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">{cards.map(([label, value, Icon]) => <div key={label} className="glass flex items-center gap-4 p-4"><span className="rounded-xl bg-lime-300/10 p-3 text-lime-300"><Icon size={20}/></span><div><div className="text-2xl font-semibold">{value}</div><div className="text-xs text-white/50">{label}</div></div></div>)}</div>
    <div className="glass grid gap-3 p-4 md:grid-cols-[1fr_180px_180px]">
      <input value={search} onChange={event => setSearch(event.target.value)} placeholder="Email, reason or details" className="rounded-xl border border-white/10 bg-black/20 px-4 py-3 text-sm outline-none focus:border-lime-300/60" />
      <select value={status} onChange={event => setStatus(event.target.value)} className="rounded-xl border border-white/10 bg-black/40 px-3 py-3 text-sm"><option value="open">Open</option><option value="reviewing">Reviewing</option><option value="resolved">Resolved</option><option value="dismissed">Dismissed</option><option value="">All statuses</option></select>
      <select value={source} onChange={event => setSource(event.target.value)} className="rounded-xl border border-white/10 bg-black/40 px-3 py-3 text-sm"><option value="">All sources</option><option value="social_profile">Friends</option><option value="professional_profile">Network</option><option value="marketplace_listing">Marketplace</option><option value="event">Events</option><option value="chat_message">Chat</option><option value="job">Jobs</option><option value="discovery_review">Reviews</option><option value="social_profile_review">Profile review</option><option value="professional_profile_review">Professional review</option></select>
    </div>
    {error && <div className="rounded-xl border border-red-400/30 bg-red-400/10 p-3 text-sm text-red-200">{error}</div>}
    <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_420px]">
      <div className="space-y-3">{cases.length === 0 && <div className="glass p-10 text-center text-white/45">Queue empty</div>}{cases.map(item => <button key={item.id} onClick={() => beginReview(item).catch(error => setError(error.message))} className={`glass w-full p-5 text-left transition hover:border-lime-300/30 ${selected?.id === item.id ? 'border-lime-300/60' : ''}`}><div className="flex flex-wrap items-center gap-2"><span className={`rounded-full px-2 py-1 text-[10px] font-semibold uppercase ${item.priority === 'critical' || item.priority === 'high' ? 'bg-red-400/15 text-red-200' : 'bg-white/8 text-white/55'}`}>{item.priority}</span><span className="rounded-full bg-lime-300/10 px-2 py-1 text-[10px] uppercase text-lime-300">{item.source_type.replaceAll('_', ' ')}</span><span className="ml-auto text-xs text-white/35">{item.created_at ? new Date(item.created_at).toLocaleString() : ''}</span></div><div className="mt-3 font-semibold">{item.reason}</div><div className="mt-1 text-sm text-white/55">{item.subject_email || item.subject_user_id || 'Content-only report'}</div>{item.details && <div className="mt-3 line-clamp-2 text-sm text-white/65">{item.details}</div>}<div className="mt-4 flex gap-4 text-xs text-white/40"><span>{item.subject_strikes} strikes</span><span>{item.status}</span></div></button>)}</div>
      <aside className="xl:sticky xl:top-6 xl:self-start">{selected ? <div className="glass space-y-5 p-5"><div><div className="text-xs uppercase tracking-widest text-lime-300">Case context</div><h2 className="mt-2 text-xl font-semibold">{selected.reason}</h2><div className="mt-1 text-sm text-white/50">{selected.subject_email}</div></div><pre className="max-h-56 overflow-auto whitespace-pre-wrap rounded-xl bg-black/25 p-3 text-xs text-white/55">{JSON.stringify(selected.context, null, 2)}</pre>{selected.actions.length > 0 && <div><div className="mb-2 text-sm font-semibold">History</div>{selected.actions.map(action => <div key={action.id} className="border-l border-white/15 py-2 pl-3 text-xs"><b>{action.action}</b><div className="text-white/50">{action.comment}</div></div>)}</div>}<textarea value={comment} onChange={event => setComment(event.target.value)} placeholder="Required moderator comment" rows={4} className="w-full rounded-xl border border-white/10 bg-black/25 p-3 text-sm outline-none focus:border-lime-300/60"/><div className="flex items-center gap-3"><span className="text-xs text-white/45">Suspend days</span><input type="number" min={1} max={365} value={days} onChange={event => setDays(Number(event.target.value))} className="w-20 rounded-lg border border-white/10 bg-black/30 px-2 py-2 text-sm"/></div><div className="grid grid-cols-2 gap-2">{(selected.source_type.endsWith('_profile_review') ? profileActions : actions).map(({ id, label, icon: Icon }) => <button disabled={busy} key={id} onClick={() => decide(id)} className={`flex items-center justify-center gap-2 rounded-xl border px-3 py-3 text-sm font-medium transition disabled:opacity-40 ${id === 'ban' || id === 'reject' ? 'border-red-400/30 text-red-200 hover:bg-red-400/10' : 'border-white/10 hover:bg-white/10'}`}><Icon size={16}/>{label}</button>)}</div></div> : <div className="glass p-8 text-center text-sm text-white/40">Select report to review context and take action.</div>}</aside>
    </div>
  </div>
}

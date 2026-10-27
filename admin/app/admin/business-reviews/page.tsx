"use client"

import { useCallback, useEffect, useState } from "react"
import { EyeOff, RefreshCw, Star, Undo2 } from "lucide-react"
import toast from "react-hot-toast"

type Review = {
  id: string
  business_user_id: string
  author_name: string
  rating: number
  text: string
  owner_reply?: string | null
  status: "published" | "hidden"
  created_at: string
}

const date = (value: string) => new Intl.DateTimeFormat("de-CH", { dateStyle: "medium" }).format(new Date(value))

export default function BusinessReviewsPage() {
  const [rows, setRows] = useState<Review[]>([])
  const [status, setStatus] = useState<"published" | "hidden">("published")
  const [loading, setLoading] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const response = await fetch(`/api/admin/business-reviews?status=${status}`, { cache: "no-store" })
      const body = await response.json().catch(() => [])
      if (!response.ok) throw new Error(body.detail || "Reviews could not be loaded")
      setRows(Array.isArray(body) ? body : [])
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Reviews could not be loaded")
    } finally { setLoading(false) }
  }, [status])

  useEffect(() => { void load() }, [load])

  async function moderate(review: Review, next: Review["status"]) {
    const response = await fetch(`/api/admin/business-reviews/${review.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ status: next }),
    })
    const body = await response.json().catch(() => ({}))
    if (!response.ok) { toast.error(body.detail || "Update failed"); return }
    setRows(current => current.filter(row => row.id !== review.id))
    toast.success(next === "hidden" ? "Review hidden, rating recalculated" : "Review published again")
  }

  return <section className="space-y-6 pb-12">
    <header className="flex flex-col justify-between gap-4 rounded-[28px] border border-lime-300/20 bg-[#0d140e] p-6 md:flex-row md:items-end md:p-8">
      <div><div className="flex items-center gap-2 text-xs font-bold uppercase tracking-[.22em] text-lime-300"><Star size={16} /> Business reviews</div><h1 className="mt-3 text-3xl font-black md:text-4xl">Review moderation</h1><p className="mt-3 max-w-2xl text-sm leading-6 text-white/55">Only clients with a past Sweezy appointment can review. Hide abusive or off-topic reviews; the business rating updates immediately.</p></div>
      <div className="flex gap-2">
        <select aria-label="Status" value={status} onChange={event => setStatus(event.target.value as Review["status"])} className="h-11 rounded-xl border border-white/10 bg-[#111511] px-3"><option value="published">Published</option><option value="hidden">Hidden</option></select>
        <button onClick={() => void load()} disabled={loading} className="flex min-h-11 items-center gap-2 rounded-xl border border-white/10 bg-white/[.05] px-4 text-sm font-semibold"><RefreshCw size={16} className={loading ? "animate-spin" : ""} /> Refresh</button>
      </div>
    </header>
    <div className="grid gap-3 md:grid-cols-2">
      {rows.map(review => <article key={review.id} className="rounded-[22px] border border-white/10 bg-white/[.03] p-5">
        <div className="flex items-start justify-between gap-3">
          <div><h2 className="font-bold">{review.author_name}</h2><p className="text-xs text-white/40">{date(review.created_at)} · business {review.business_user_id.slice(0, 8)}</p></div>
          <span className="text-lime-300" aria-label={`${review.rating} of 5`}>{"★".repeat(review.rating)}<span className="text-white/20">{"★".repeat(5 - review.rating)}</span></span>
        </div>
        {review.text && <p className="mt-3 whitespace-pre-line text-sm leading-6 text-white/70">{review.text}</p>}
        {review.owner_reply && <p className="mt-3 rounded-xl bg-black/20 p-3 text-xs text-white/50">Owner: {review.owner_reply}</p>}
        <button onClick={() => void moderate(review, review.status === "published" ? "hidden" : "published")} className="mt-4 flex min-h-10 items-center gap-2 rounded-xl border border-white/10 px-3 text-sm font-semibold">
          {review.status === "published" ? <><EyeOff size={15} /> Hide</> : <><Undo2 size={15} /> Publish again</>}
        </button>
      </article>)}
      {!rows.length && <div className="col-span-full rounded-[22px] border border-dashed border-white/10 p-12 text-center text-sm text-white/40">{loading ? "Loading…" : "No reviews."}</div>}
    </div>
  </section>
}

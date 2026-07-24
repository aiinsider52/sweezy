"use client"

import { useEffect, useState } from "react"

type Question = {
  id: string
  listing_id: string
  asker_name: string | null
  asker_language: string | null
  question_text: string
  answer_text: string | null
  status: "pending" | "answered" | "rejected" | string
  answered_at: string | null
  created_at: string
}

export default function ExpertQuestionsList() {
  const [items, setItems] = useState<Question[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState<"pending" | "answered" | "rejected" | "all">("pending")
  const [busyId, setBusyId] = useState<string | null>(null)
  const [drafts, setDrafts] = useState<Record<string, string>>({})

  async function load() {
    setLoading(true)
    try {
      const qs = filter === "all" ? "" : `?status=${filter}`
      const res = await fetch(`/api/admin/expert-questions${qs}`, { cache: "no-store" })
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
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filter])

  async function answer(id: string) {
    const text = drafts[id]?.trim()
    if (!text) return
    setBusyId(id)
    try {
      const res = await fetch(`/api/admin/expert-questions/${id}/answer`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ answer_text: text }),
      })
      if (res.ok) {
        setDrafts(prev => ({ ...prev, [id]: "" }))
        await load()
      }
    } finally {
      setBusyId(null)
    }
  }

  async function reject(id: string) {
    if (!window.confirm("Reject this question?")) return
    setBusyId(id)
    try {
      await fetch(`/api/admin/expert-questions/${id}/reject`, { method: "PATCH" })
      await load()
    } finally {
      setBusyId(null)
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-2">
        {(["pending", "answered", "rejected", "all"] as const).map(value => (
          <button
            key={value}
            onClick={() => setFilter(value)}
            className={`rounded-lg px-3 py-2 text-sm transition ${filter === value ? "bg-white/20" : "bg-white/5 hover:bg-white/10"}`}
          >
            {value[0].toUpperCase() + value.slice(1)}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="glass rounded-xl p-6">Loading questions…</div>
      ) : items.length === 0 ? (
        <div className="glass rounded-xl p-6">No questions in this bucket.</div>
      ) : (
        <div className="space-y-3">
          {items.map(item => (
            <div key={item.id} className="glass space-y-3 rounded-2xl p-4">
              <div className="flex flex-wrap items-center gap-2 text-xs opacity-70">
                <span className="rounded-full bg-white/10 px-2 py-1">{item.status}</span>
                <span>listing: {item.listing_id}</span>
                <span>{new Date(item.created_at).toLocaleString()}</span>
                {item.asker_language && <span>lang: {item.asker_language}</span>}
              </div>
              <div className="text-sm whitespace-pre-wrap">{item.question_text}</div>

              {item.answer_text ? (
                <div className="rounded-xl bg-emerald-500/10 p-3 text-sm text-emerald-100 whitespace-pre-wrap">
                  {item.answer_text}
                </div>
              ) : item.status === "pending" ? (
                <div className="space-y-2">
                  <textarea
                    placeholder="Type your answer (visible publicly under expert profile)…"
                    className="min-h-24 w-full rounded-lg border border-white/10 bg-white/5 p-2 text-sm outline-none"
                    value={drafts[item.id] ?? ""}
                    onChange={e => setDrafts(prev => ({ ...prev, [item.id]: e.target.value }))}
                  />
                  <div className="flex gap-2">
                    <button
                      disabled={busyId === item.id || !(drafts[item.id]?.trim())}
                      onClick={() => answer(item.id)}
                      className="rounded-lg bg-emerald-500/20 px-3 py-2 text-sm text-emerald-200 disabled:opacity-50"
                    >
                      {busyId === item.id ? "…" : "Publish answer"}
                    </button>
                    <button
                      disabled={busyId === item.id}
                      onClick={() => reject(item.id)}
                      className="rounded-lg bg-red-500/20 px-3 py-2 text-sm text-red-200 disabled:opacity-50"
                    >
                      Reject
                    </button>
                  </div>
                </div>
              ) : null}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

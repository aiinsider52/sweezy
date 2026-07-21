"use client"

import { useCallback, useEffect, useState } from "react"

type Message = {
  id: string
  sender_id: string
  body: string
  created_at: string
}

type Report = {
  id: string
  status: string
  reason: string
  details?: string | null
  created_at: string
  reporter_id: string
  message: Message
  context: Message[]
}

export default function ChatReportsList() {
  const [status, setStatus] = useState("open")
  const [reports, setReports] = useState<Report[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")

  const load = useCallback(async () => {
    setLoading(true)
    setError("")
    try {
      const response = await fetch(`/api/admin/chat/reports?status=${status}`, { cache: "no-store" })
      if (!response.ok) throw new Error(await response.text())
      setReports(await response.json())
    } catch (value) {
      setError(value instanceof Error ? value.message : "Failed to load reports")
    } finally {
      setLoading(false)
    }
  }, [status])

  useEffect(() => { void load() }, [load])

  async function update(id: string, nextStatus: "resolved" | "dismissed") {
    const response = await fetch(`/api/admin/chat/reports/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ status: nextStatus }),
    })
    if (!response.ok) {
      setError(await response.text())
      return
    }
    setReports(current => current.filter(report => report.id !== id))
  }

  return (
    <div className="space-y-5">
      <div className="flex gap-2">
        {["open", "resolved", "dismissed"].map(value => (
          <button
            key={value}
            onClick={() => setStatus(value)}
            className={`rounded-full px-4 py-2 text-sm ${status === value ? "bg-lime-300 text-black" : "bg-white/10"}`}
          >
            {value}
          </button>
        ))}
      </div>
      {error && <div className="rounded-xl border border-red-400/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</div>}
      {loading && <div className="opacity-60">Loading reported messages…</div>}
      {!loading && reports.length === 0 && <div className="opacity-60">No {status} chat reports.</div>}
      {reports.map(report => (
        <article key={report.id} className="rounded-2xl border border-white/10 bg-black/20 p-5 space-y-4">
          <div className="flex items-start justify-between gap-4">
            <div>
              <div className="font-semibold">{report.reason}</div>
              <div className="text-xs opacity-50">{new Date(report.created_at).toLocaleString()} · reporter {report.reporter_id}</div>
              {report.details && <div className="mt-2 text-sm opacity-75">{report.details}</div>}
            </div>
            <span className="rounded-full bg-red-500/15 px-3 py-1 text-xs text-red-200">{report.status}</span>
          </div>
          <div className="rounded-xl border border-red-400/30 bg-red-500/10 p-3">
            <div className="mb-1 text-xs uppercase tracking-wide text-red-200">Reported message</div>
            <div>{report.message.body}</div>
          </div>
          <details className="rounded-xl bg-white/5 p-3">
            <summary className="cursor-pointer text-sm font-medium">Bounded context ({report.context.length} messages)</summary>
            <div className="mt-3 space-y-2">
              {report.context.map(message => (
                <div key={message.id} className="rounded-lg bg-black/20 p-2 text-sm">
                  <span className="mr-2 text-xs opacity-50">{message.sender_id}</span>{message.body}
                </div>
              ))}
            </div>
          </details>
          {status === "open" && (
            <div className="flex gap-2">
              <button onClick={() => void update(report.id, "resolved")} className="rounded-lg bg-lime-300 px-4 py-2 text-sm font-semibold text-black">Resolve</button>
              <button onClick={() => void update(report.id, "dismissed")} className="rounded-lg bg-white/10 px-4 py-2 text-sm">Dismiss</button>
            </div>
          )}
        </article>
      ))}
    </div>
  )
}

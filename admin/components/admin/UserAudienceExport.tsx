'use client'

import { useState } from 'react'

type Props = {
  filters: Record<string, string>
}

export default function UserAudienceExport({ filters }: Props) {
  const [open, setOpen] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  async function exportAudience() {
    setLoading(true)
    setError('')
    try {
      const query = new URLSearchParams(filters)
      query.set('purpose', 'meta_custom_audience')
      const response = await fetch(`/api/admin/users/export?${query}`, { method: 'POST' })
      if (!response.ok) {
        const body = await response.json().catch(() => null)
        throw new Error(body?.detail || body?.error || 'Export failed')
      }
      const blob = await response.blob()
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = 'meta-custom-audience-sha256.csv'
      document.body.appendChild(link)
      link.click()
      link.remove()
      URL.revokeObjectURL(url)
      setOpen(false)
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Export failed')
    } finally {
      setLoading(false)
    }
  }

  if (!open) {
    return (
      <button className="glass px-3 py-2 rounded-lg text-sm" type="button" onClick={() => setOpen(true)}>
        Export ad audience
      </button>
    )
  }

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/60 p-4" role="dialog" aria-modal="true" aria-labelledby="audience-export-title">
      <div className="glass max-w-lg rounded-xl p-6 shadow-xl">
        <h2 id="audience-export-title" className="text-lg font-semibold">Confirm privacy-safe audience export</h2>
        <p className="mt-3 text-sm opacity-80">
          This exports only verified email identifiers normalized and SHA-256 hashed for Meta Custom Audiences.
          No raw email, user ID, role, subscription, or account metadata is included.
        </p>
        <p className="mt-2 text-sm opacity-80">
          The current filters, your admin identity, purpose, row count, timestamp, and outcome are recorded in the audit log.
          Upload and retain this file only under your organization&apos;s approved advertising and consent policy.
        </p>
        {error && <p className="mt-3 text-sm text-red-400" role="alert">{error}</p>}
        <div className="mt-5 flex justify-end gap-2">
          <button className="glass px-3 py-2 rounded-lg text-sm" type="button" disabled={loading} onClick={() => setOpen(false)}>
            Cancel
          </button>
          <button className="glass px-3 py-2 rounded-lg text-sm" type="button" disabled={loading} onClick={exportAudience}>
            {loading ? 'Generating…' : 'Confirm and download'}
          </button>
        </div>
      </div>
    </div>
  )
}

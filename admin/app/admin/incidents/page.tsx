'use client'

import { useCallback, useEffect, useState } from 'react'
import Card from '@/components/Card'
import Button from '@/components/ui/button'

type Incident = {
  id: string
  source: string
  severity: string
  title: string
  message?: string
  status: 'open' | 'resolved'
  occurrence_count: number
  last_seen_at: string
}

export default function IncidentsPage() {
  const [items, setItems] = useState<Incident[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    const response = await fetch('/api/admin/incidents?limit=200', { cache: 'no-store' })
    if (!response.ok) {
      setError('Could not load incidents.')
    } else {
      setItems(await response.json())
      setError('')
    }
    setLoading(false)
  }, [])

  useEffect(() => { void load() }, [load])

  async function setStatus(item: Incident) {
    const response = await fetch(`/api/admin/incidents/${item.id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: item.status === 'open' ? 'resolved' : 'open' }),
    })
    if (response.ok) await load()
  }

  async function testAlert() {
    const response = await fetch('/api/admin/incidents/test-alert', { method: 'POST' })
    setError(response.ok ? 'Test alert sent.' : 'Test alert failed or was rate limited.')
    if (response.ok) await load()
  }

  return (
    <section className="space-y-6">
      <Card title="Incidents">
        <div className="mb-4 flex items-center justify-between gap-4">
          <p className="text-sm opacity-70">Deduplicated operational alerts. Sensitive values are redacted.</p>
          <Button onClick={testAlert}>Send test alert</Button>
        </div>
        {error && <p role="status" className="mb-4 text-sm text-amber-300">{error}</p>}
        {loading ? <p className="opacity-70">Loading…</p> : (
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="text-left opacity-70">
                <tr>
                  <th className="px-3 py-2">Last seen</th><th className="px-3 py-2">Severity</th>
                  <th className="px-3 py-2">Source</th><th className="px-3 py-2">Incident</th>
                  <th className="px-3 py-2">Count</th><th className="px-3 py-2">Status</th>
                </tr>
              </thead>
              <tbody>
                {items.map(item => (
                  <tr key={item.id} className="border-t border-white/10 align-top">
                    <td className="whitespace-nowrap px-3 py-3">{new Date(item.last_seen_at).toLocaleString()}</td>
                    <td className="px-3 py-3 uppercase">{item.severity}</td>
                    <td className="px-3 py-3">{item.source}</td>
                    <td className="max-w-xl px-3 py-3"><strong>{item.title}</strong><div className="opacity-70">{item.message}</div></td>
                    <td className="px-3 py-3">{item.occurrence_count}</td>
                    <td className="px-3 py-3"><Button variant="default" onClick={() => setStatus(item)}>{item.status}</Button></td>
                  </tr>
                ))}
                {!items.length && <tr><td colSpan={6} className="px-3 py-6 opacity-70">No incidents recorded.</td></tr>}
              </tbody>
            </table>
          </div>
        )}
      </Card>
    </section>
  )
}

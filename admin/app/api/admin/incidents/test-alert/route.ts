import { serverFetch } from '@/lib/server'

export async function POST() {
  const response = await serverFetch('/admin/incidents/test-alert', { method: 'POST' })
  return new Response(await response.text(), {
    status: response.status,
    headers: { 'Content-Type': 'application/json' },
  })
}

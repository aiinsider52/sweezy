import { serverFetch } from '@/lib/server'

export async function GET() {
  const response = await serverFetch('/admin/reports-safety/stats')
  return new Response(await response.text(), { status: response.status, headers: { 'Content-Type': 'application/json' } })
}

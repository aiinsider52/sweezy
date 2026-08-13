import { NextRequest } from 'next/server'
import { serverFetch } from '@/lib/server'

export async function PATCH(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const response = await serverFetch(`/admin/reports-safety/${encodeURIComponent(id)}`, { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: await request.text() })
  return new Response(await response.text(), { status: response.status, headers: { 'Content-Type': 'application/json' } })
}

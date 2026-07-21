import { NextRequest, NextResponse } from 'next/server'
import { serverFetch } from '@/lib/server'

export async function PATCH(req: NextRequest, props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  const body = await req.json()
  const res = await serverFetch(`/admin/brave-news/queries/${params.id}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  const text = await res.text()
  return new NextResponse(text, { status: res.status })
}

export async function DELETE(_: NextRequest, props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  const res = await serverFetch(`/admin/brave-news/queries/${params.id}`, { method: 'DELETE' })
  const text = await res.text()
  return new NextResponse(text || null, { status: res.status })
}

import { NextRequest, NextResponse } from 'next/server'
import { serverFetch } from '@/lib/server'

export async function PUT(req: NextRequest, { params }: { params: { id: string } }) {
  const body = await req.json()
  const res = await serverFetch(`/admin/news/${params.id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  const text = await res.text()
  return new NextResponse(text, { status: res.status })
}

export async function DELETE(req: NextRequest, { params }: { params: { id: string } }) {
  const res = await serverFetch(`/admin/news/${params.id}`, { method: 'DELETE' })
  return new NextResponse(null, { status: res.status })
}



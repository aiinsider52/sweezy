import { NextRequest, NextResponse } from 'next/server'
import { serverFetch } from '@/lib/server'

export async function GET() {
  const res = await serverFetch('/admin/brave-news/queries')
  const text = await res.text()
  return new NextResponse(text, { status: res.status })
}

export async function POST(req: NextRequest) {
  const body = await req.json()
  const res = await serverFetch('/admin/brave-news/queries', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  const text = await res.text()
  return new NextResponse(text, { status: res.status })
}

import { NextRequest, NextResponse } from 'next/server'
import { serverFetch } from '@/lib/server'

export async function GET() {
  const res = await serverFetch('/news/?limit=100')
  const text = await res.text()
  try {
    return new NextResponse(text, { status: res.status })
  } catch {
    return NextResponse.json({ error: 'Failed to fetch news' }, { status: 500 })
  }
}

export async function POST(req: NextRequest) {
  const body = await req.json()
  const res = await serverFetch('/news/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  const text = await res.text()
  return new NextResponse(text, { status: res.status })
}



import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import { API_URL } from '@/lib/api'

export async function GET() {
  const token = (await cookies()).get('access_token')?.value
  const res = await fetch(`${API_URL}/admin/rss-feeds`, {
    headers: token ? { Authorization: `Bearer ${token}` } : undefined,
    cache: 'no-store'
  })
  const text = await res.text()
  return new NextResponse(text, { status: res.status, headers: { 'content-type': res.headers.get('content-type') || 'application/json' } })
}

export async function POST(req: NextRequest) {
  const token = (await cookies()).get('access_token')?.value
  const body = await req.text()
  const res = await fetch(`${API_URL}/admin/rss-feeds`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body
  })
  const text = await res.text()
  return new NextResponse(text, { status: res.status, headers: { 'content-type': res.headers.get('content-type') || 'application/json' } })
}



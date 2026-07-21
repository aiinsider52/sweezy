import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import { API_URL } from '@/lib/api'

export async function POST(req: NextRequest) {
  const token = (await cookies()).get('access_token')?.value
  const form = await req.formData()
  const res = await fetch(`${API_URL}/media/upload`, {
    method: 'POST',
    headers: token ? { Authorization: `Bearer ${token}` } : undefined,
    body: form as any,
    cache: 'no-store'
  })
  const text = await res.text()
  return new NextResponse(text, { status: res.status, headers: { 'content-type': res.headers.get('content-type') || 'application/json' } })
}



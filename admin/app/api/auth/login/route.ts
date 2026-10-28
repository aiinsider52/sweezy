import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import { verifyAdminToken } from '@/lib/admin-auth'

export async function GET(req: NextRequest) {
  return NextResponse.redirect(new URL('/login', req.url))
}

export async function POST(req: NextRequest) {
  const { email, password } = await req.json()
  const api = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy-api.onrender.com/api/v1'
  const res = await fetch(`${api}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  })
  const text = await res.text()
  if (!res.ok) {
    // Render answers 502/503 with an HTML page while the free API instance wakes up.
    if (res.status >= 500 || text.trimStart().startsWith('<')) {
      return new NextResponse('API is waking up — try again in a minute', { status: 503 })
    }
    return new NextResponse(text || 'Login failed', { status: res.status })
  }
  let payload: { access_token?: string } = {}
  try { payload = JSON.parse(text) } catch {}
  if (!payload.access_token || !(await verifyAdminToken(payload.access_token))) {
    return NextResponse.json({ error: 'Administrator access required' }, { status: 403 })
  }
  if (payload.access_token) {
    (await cookies()).set('access_token', payload.access_token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 60*60*24
    })
  }
  return NextResponse.json({ authenticated: true })
}



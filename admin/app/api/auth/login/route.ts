import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'

export async function POST(req: NextRequest) {
  const { email, password } = await req.json()
  const api = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy-9xyk.onrender.com/api/v1'
  const res = await fetch(`${api}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  })
  const text = await res.text()
  if (!res.ok) return new NextResponse(text || 'Login failed', { status: res.status })
  let payload: any = {}
  try { payload = JSON.parse(text) } catch {}
  if (payload?.access_token) {
    cookies().set('access_token', payload.access_token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 60*60*24
    })
  }
  return NextResponse.json(payload)
}



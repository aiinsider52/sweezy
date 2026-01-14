import { NextResponse } from 'next/server'

export async function GET() {
  const api = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy-9xyk.onrender.com/api/v1'
  const res = await fetch(`${api}/jobs/analytics/top`, { cache: 'no-store' })
  const text = await res.text()
  if (!res.ok) return new NextResponse(text || 'Failed', { status: res.status })
  return new NextResponse(text, { status: 200, headers: { 'Content-Type': 'application/json' } })
}



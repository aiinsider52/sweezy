import { NextRequest, NextResponse } from 'next/server'

export async function GET(req: NextRequest) {
  const api = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy-9xyk.onrender.com/api/v1'
  const query = req.nextUrl.searchParams.toString()
  const url = `${api}/jobs/search${query ? `?${query}` : ''}`
  const res = await fetch(url, { cache: 'no-store' })
  const text = await res.text()
  if (!res.ok) return new NextResponse(text || 'Search failed', { status: res.status })
  return new NextResponse(text, { status: 200, headers: { 'Content-Type': 'application/json' } })
}


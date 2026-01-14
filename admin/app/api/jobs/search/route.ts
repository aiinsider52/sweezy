import { NextRequest, NextResponse } from 'next/server'

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url)
  const q = searchParams.get('q') || ''
  const canton = searchParams.get('canton') || ''
  const page = searchParams.get('page') || '1'
  const per_page = searchParams.get('per_page') || '20'
  const api = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy-9xyk.onrender.com/api/v1'
  const url = `${api}/jobs/search?q=${encodeURIComponent(q)}&canton=${encodeURIComponent(canton)}&page=${page}&per_page=${per_page}`
  const res = await fetch(url, { cache: 'no-store' })
  const text = await res.text()
  if (!res.ok) return new NextResponse(text || 'Search failed', { status: res.status })
  return new NextResponse(text, { status: 200, headers: { 'Content-Type': 'application/json' } })
}



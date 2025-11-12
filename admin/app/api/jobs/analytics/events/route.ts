import { NextRequest, NextResponse } from 'next/server'

export async function POST(req: NextRequest) {
  const { searchParams } = new URL(req.url)
  const keyword = searchParams.get('keyword') || ''
  const canton = searchParams.get('canton') || ''
  const api = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy.onrender.com/api/v1'
  const res = await fetch(`${api}/jobs/analytics/events?keyword=${encodeURIComponent(keyword)}&canton=${encodeURIComponent(canton)}`, {
    method: 'POST'
  })
  return new NextResponse(null, { status: res.status })
}



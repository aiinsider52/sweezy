import { NextRequest, NextResponse } from 'next/server'

export async function POST(req: NextRequest) {
  const api = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy-9xyk.onrender.com/api/v1'
  const payload = await req.json()
  const res = await fetch(`${api}/ai/job-apply`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  })
  const text = await res.text()
  if (!res.ok) return new NextResponse(text || 'Failed', { status: res.status })
  return NextResponse.json(JSON.parse(text))
}



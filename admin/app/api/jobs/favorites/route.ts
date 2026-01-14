import { cookies } from 'next/headers'
import { NextRequest, NextResponse } from 'next/server'

const api = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy-9xyk.onrender.com/api/v1'

export async function GET() {
  const token = cookies().get('access_token')?.value
  if (!token) return NextResponse.json([], { status: 200 })
  const res = await fetch(`${api}/jobs/favorites`, { headers: { Authorization: `Bearer ${token}` }, cache: 'no-store' })
  const text = await res.text()
  if (!res.ok) return new NextResponse(text || 'Failed', { status: res.status })
  return NextResponse.json(JSON.parse(text))
}

export async function POST(req: NextRequest) {
  const token = cookies().get('access_token')?.value
  if (!token) return new NextResponse('Unauthorized', { status: 401 })
  const payload = await req.json()
  const res = await fetch(`${api}/jobs/favorites`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify(payload)
  })
  const text = await res.text()
  if (!res.ok) return new NextResponse(text || 'Failed', { status: res.status })
  return NextResponse.json(JSON.parse(text))
}



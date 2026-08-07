import { NextRequest, NextResponse } from 'next/server'
import { serverFetch } from '@/lib/server'

const RANGE_DAYS: Record<string, string> = {
  '7d': '7',
  '30d': '30',
  '90d': '90',
  '365d': '365',
}

export async function GET(request: NextRequest) {
  const range = request.nextUrl.searchParams.get('range') ?? '30d'
  const days = request.nextUrl.searchParams.get('days') ?? RANGE_DAYS[range] ?? '30'
  const query = new URLSearchParams({ days })

  try {
    const response = await serverFetch(`/admin/users/registrations?${query}`)
    const body = await response.text()
    return new NextResponse(body, {
      status: response.status,
      headers: {
        'Content-Type': response.headers.get('Content-Type') || 'application/json',
        'Cache-Control': 'private, no-store',
      },
    })
  } catch {
    return NextResponse.json(
      { detail: 'Registration analytics are temporarily unavailable.' },
      { status: 502 },
    )
  }
}

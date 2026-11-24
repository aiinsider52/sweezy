import { NextRequest, NextResponse } from 'next/server'
import { serverFetch } from '@/lib/server'

const RANGE_DAYS: Record<string, string> = { '7d': '7', '30d': '30', '90d': '90', '365d': '180' }

export async function GET(request: NextRequest) {
  const range = request.nextUrl.searchParams.get('range') ?? '30d'
  try {
    const response = await serverFetch(`/admin/analytics/growth?days=${RANGE_DAYS[range] ?? '30'}`)
    return new NextResponse(await response.text(), {
      status: response.status,
      headers: {
        'Content-Type': response.headers.get('Content-Type') || 'application/json',
        'Cache-Control': 'private, no-store',
      },
    })
  } catch {
    return NextResponse.json({ detail: 'Growth analytics is temporarily unavailable.' }, { status: 502 })
  }
}

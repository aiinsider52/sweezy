import { NextRequest, NextResponse } from 'next/server'
import { serverFetch } from '@/lib/server'

const RANGE_DAYS: Record<string, string> = {
  '7d': '7',
  '30d': '30',
  '90d': '90',
  '365d': '365',
}

export async function GET(request: NextRequest) {
  const query = new URLSearchParams()
  const range = request.nextUrl.searchParams.get('range') ?? '30d'
  query.set('days', RANGE_DAYS[range] ?? '30')
  const appVersion = request.nextUrl.searchParams.get('app_version')
  if (appVersion && appVersion.length <= 64) query.set('app_version', appVersion)

  try {
    const suffix = query.size ? `?${query.toString()}` : ''
    const response = await serverFetch(`/admin/analytics/overview${suffix}`)
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
      { detail: 'Analytics service is temporarily unavailable.' },
      { status: 502 },
    )
  }
}

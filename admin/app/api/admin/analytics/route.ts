import { NextRequest, NextResponse } from 'next/server'
import { serverFetch } from '@/lib/server'

const ALLOWED_PARAMS = new Set(['range', 'start_date', 'end_date', 'app_version'])

export async function GET(request: NextRequest) {
  const query = new URLSearchParams()
  request.nextUrl.searchParams.forEach((value, key) => {
    if (ALLOWED_PARAMS.has(key) && value.length <= 64) query.set(key, value)
  })

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

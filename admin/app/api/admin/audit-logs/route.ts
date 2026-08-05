import { NextRequest, NextResponse } from 'next/server'
import { serverFetch } from '@/lib/server'

export async function GET(req: NextRequest) {
  const res = await serverFetch(`/admin/audit-logs?${req.nextUrl.searchParams.toString()}`)
  const text = await res.text()
  return new NextResponse(text, { status: res.status, headers: { 'content-type': res.headers.get('content-type') || 'application/json' } })
}



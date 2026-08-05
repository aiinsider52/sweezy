import { NextRequest, NextResponse } from 'next/server'
import { serverFetch } from '@/lib/server'

export async function GET(req: NextRequest) {
  const res = await serverFetch(`/admin/audit-logs/export?${req.nextUrl.searchParams.toString()}`)
  const body = await res.arrayBuffer()
  return new NextResponse(body, {
    status: res.status,
    headers: {
      'content-type': res.headers.get('content-type') || 'text/csv',
      'content-disposition': res.headers.get('content-disposition') || 'attachment; filename="audit-logs.csv"',
    },
  })
}

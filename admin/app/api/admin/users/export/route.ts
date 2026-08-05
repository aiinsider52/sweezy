import { NextRequest, NextResponse } from 'next/server'
import { serverFetch } from '@/lib/server'

export async function POST(req: NextRequest) {
  const res = await serverFetch(`/admin/users/export?${req.nextUrl.searchParams.toString()}`, { method: 'POST' })
  const body = await res.arrayBuffer()
  return new NextResponse(body, {
    status: res.status,
    headers: {
      'content-type': res.headers.get('content-type') || 'text/csv',
      'content-disposition': res.headers.get('content-disposition') || 'attachment; filename="users.csv"',
      'x-export-row-count': res.headers.get('x-export-row-count') || '',
    },
  })
}

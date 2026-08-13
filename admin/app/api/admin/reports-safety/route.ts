import { NextRequest } from 'next/server'
import { serverFetch } from '@/lib/server'

export async function GET(request: NextRequest) {
  const query = request.nextUrl.searchParams.toString()
  const response = await serverFetch(`/admin/reports-safety${query ? `?${query}` : ''}`)
  return new Response(await response.text(), { status: response.status, headers: { 'Content-Type': 'application/json' } })
}

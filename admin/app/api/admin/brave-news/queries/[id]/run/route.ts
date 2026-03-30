import { NextRequest, NextResponse } from 'next/server'
import { serverFetch } from '@/lib/server'

export async function POST(_: NextRequest, { params }: { params: { id: string } }) {
  const res = await serverFetch(`/admin/brave-news/queries/${params.id}/run`, {
    method: 'POST',
  })
  const text = await res.text()
  return new NextResponse(text, { status: res.status })
}

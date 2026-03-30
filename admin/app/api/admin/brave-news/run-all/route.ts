import { NextResponse } from 'next/server'
import { serverFetch } from '@/lib/server'

export async function POST() {
  const res = await serverFetch('/admin/brave-news/run-all', {
    method: 'POST',
  })
  const text = await res.text()
  return new NextResponse(text, { status: res.status })
}

import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import { API_URL } from '@/lib/api'

export async function PUT(req: NextRequest, { params }: { params: { id: string } }) {
  const token = cookies().get('access_token')?.value
  const body = await req.text()
  const res = await fetch(`${API_URL}/templates/${params.id}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    },
    body
  })
  const text = await res.text()
  return new NextResponse(text, {
    status: res.status,
    headers: { 'content-type': res.headers.get('content-type') || 'application/json' }
  })
}

export async function DELETE(_: NextRequest, { params }: { params: { id: string } }) {
  const token = cookies().get('access_token')?.value
  const res = await fetch(`${API_URL}/templates/${params.id}`, {
    method: 'DELETE',
    headers: token ? { Authorization: `Bearer ${token}` } : undefined
  })
  return new NextResponse(null, { status: res.status })
}


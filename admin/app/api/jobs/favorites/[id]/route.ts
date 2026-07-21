import { cookies } from 'next/headers'
import { NextRequest, NextResponse } from 'next/server'

export async function DELETE(_: NextRequest, props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  const token = (await cookies()).get('access_token')?.value
  if (!token) return new NextResponse('Unauthorized', { status: 401 })
  const api = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy-9xyk.onrender.com/api/v1'
  const res = await fetch(`${api}/jobs/favorites/${params.id}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` }
  })
  if (!res.ok) {
    const text = await res.text()
    return new NextResponse(text || 'Failed', { status: res.status })
  }
  return new NextResponse(null, { status: 204 })
}



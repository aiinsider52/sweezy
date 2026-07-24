import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import { API_URL } from '@/lib/api'

export async function DELETE(req: NextRequest, props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  const token = (await cookies()).get('access_token')?.value
  const res = await fetch(`${API_URL}/translations/glossary/${params.id}`, { method: 'DELETE', headers: token ? { Authorization: `Bearer ${token}` } : undefined })
  return new NextResponse(null, { status: res.status })
}



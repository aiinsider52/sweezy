import { getAdminToken } from '@/lib/admin-auth'
import { ADMIN_VERIFIED_HEADER } from '@/lib/admin-api-guard'
import { cookies, headers as requestHeaders } from 'next/headers'

export async function serverFetch(path: string, init?: RequestInit) {
  const base = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy-9xyk.onrender.com/api/v1'
  const verifiedByApiGuard = (await requestHeaders()).get(ADMIN_VERIFIED_HEADER) === '1'
  const token = verifiedByApiGuard
    ? (await cookies()).get('access_token')?.value ?? null
    : await getAdminToken()
  if (!token) return new Response(JSON.stringify({ error: 'Unauthorized' }), {
    status: 401,
    headers: { 'Content-Type': 'application/json' },
  })
  const headers = new Headers(init?.headers)
  headers.set('Authorization', `Bearer ${token}`)
  const controller = new AbortController()
  const timeoutMs = Number(process.env.FETCH_TIMEOUT_MS ?? 8000)
  const timer = setTimeout(() => controller.abort(), timeoutMs)
  try {
    return await fetch(`${base}${path}`, { ...init, headers, cache: 'no-store', signal: controller.signal })
  } finally {
    clearTimeout(timer)
  }
}



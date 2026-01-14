import { cookies } from 'next/headers'

export async function serverFetch(path: string, init?: RequestInit) {
  const base = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy-9xyk.onrender.com/api/v1'
  const token = cookies().get('access_token')?.value
  const headers = new Headers(init?.headers)
  if (token) headers.set('Authorization', `Bearer ${token}`)
  const controller = new AbortController()
  const timeoutMs = Number(process.env.FETCH_TIMEOUT_MS ?? 8000)
  const timer = setTimeout(() => controller.abort(), timeoutMs)
  try {
    return await fetch(`${base}${path}`, { ...init, headers, cache: 'no-store', signal: controller.signal })
  } finally {
    clearTimeout(timer)
  }
}



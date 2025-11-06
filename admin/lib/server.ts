import { cookies } from 'next/headers'

export async function serverFetch(path: string, init?: RequestInit) {
  const base = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy.onrender.com/api/v1'
  const token = cookies().get('access_token')?.value
  const headers = new Headers(init?.headers)
  if (token) headers.set('Authorization', `Bearer ${token}`)
  return fetch(`${base}${path}`, { ...init, headers, cache: 'no-store' })
}



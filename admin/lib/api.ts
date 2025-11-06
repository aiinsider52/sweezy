export const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy.onrender.com/api/v1'

export async function apiLogin(email: string, password: string) {
  const res = await fetch(`${process.env.NEXT_PUBLIC_BASE_URL ?? ''}/api/auth/login`, {
    method: 'POST',
    body: JSON.stringify({ email, password }),
    headers: { 'Content-Type': 'application/json' }
  })
  if (!res.ok) throw new Error(await res.text())
  return res.json() as Promise<{ access_token: string; refresh_token: string }>
}

export async function getUsers(token?: string) {
  const headers = token ? { Authorization: `Bearer ${token}` } : undefined
  const res = await fetch(`${API_URL}/admin/users`, { headers, cache: 'no-store' }).catch(() => null)
  if (!res || !res.ok) return []
  return res.json()
}

export async function createUser(email: string, password: string) {
  const res = await fetch(`${API_URL}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  })
  if (!res.ok) throw new Error(await res.text())
  return res.json().catch(() => ({}))
}



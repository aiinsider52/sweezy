import { cookies } from 'next/headers'

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy-9xyk.onrender.com/api/v1'

type CurrentUser = {
  role?: string | null
  is_superuser?: boolean
}

export function isAdmin(user: CurrentUser): boolean {
  return user.is_superuser === true || user.role?.toLowerCase() === 'admin'
}

export async function verifyAdminToken(token: string | undefined): Promise<boolean> {
  if (!token) return false

  try {
    const response = await fetch(`${API_URL}/auth/me`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: 'no-store',
      signal: AbortSignal.timeout(Number(process.env.FETCH_TIMEOUT_MS ?? 8000)),
    })
    if (!response.ok) return false
    return isAdmin(await response.json())
  } catch {
    return false
  }
}

export async function getAdminToken(): Promise<string | null> {
  const token = (await cookies()).get('access_token')?.value
  return (await verifyAdminToken(token)) ? token! : null
}

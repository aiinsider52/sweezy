import { NextRequest, NextResponse } from 'next/server'
import { verifyAdminToken } from '@/lib/admin-auth'

export const ADMIN_VERIFIED_HEADER = 'x-sweezy-admin-verified'

export async function guardAdminApiRequest(
  request: NextRequest,
): Promise<NextResponse | null> {
  const token = request.cookies.get('access_token')?.value
  if (!(await verifyAdminToken(token))) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  return null
}

export function forwardVerifiedAdminRequest(request: NextRequest): NextResponse {
  const requestHeaders = new Headers(request.headers)
  // Always overwrite a client-supplied value. This marker is request-only and
  // prevents a second /auth/me call in serverFetch during the same BFF request.
  requestHeaders.set(ADMIN_VERIFIED_HEADER, '1')
  return NextResponse.next({ request: { headers: requestHeaders } })
}

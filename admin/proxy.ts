import { NextResponse, NextRequest } from 'next/server'
import { verifyAdminToken } from '@/lib/admin-auth'
import {
  forwardVerifiedAdminRequest,
  guardAdminApiRequest,
} from '@/lib/admin-api-guard'

export async function proxy(req: NextRequest) {
  const token = req.cookies.get('access_token')?.value
  const isAdminRoute = req.nextUrl.pathname.startsWith('/admin')
  const isApi = req.nextUrl.pathname.startsWith('/api/')
  const isAuthEndpoint = req.nextUrl.pathname === '/api/auth/login'
  const isLogin = req.nextUrl.pathname === '/login'

  if (isApi && !isAuthEndpoint) {
    const rejection = await guardAdminApiRequest(req)
    return rejection ?? forwardVerifiedAdminRequest(req)
  }

  const authorized = token ? await verifyAdminToken(token) : false
  if (isAdminRoute && !authorized) {
    const url = req.nextUrl.clone()
    url.pathname = '/login'
    return NextResponse.redirect(url)
  }

  if (isLogin && authorized) {
    const url = req.nextUrl.clone()
    url.pathname = '/admin/dashboard'
    return NextResponse.redirect(url)
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/login', '/admin/:path*', '/api/:path*']
}


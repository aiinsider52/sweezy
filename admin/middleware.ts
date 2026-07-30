import { NextResponse, NextRequest } from 'next/server'

export function middleware(req: NextRequest) {
  const token = req.cookies.get('access_token')?.value
  const isAdminRoute = req.nextUrl.pathname.startsWith('/admin')
  const isLogin = req.nextUrl.pathname === '/login'

  if (isAdminRoute && !token) {
    const url = req.nextUrl.clone()
    url.pathname = '/login'
    return NextResponse.redirect(url)
  }

  if (isLogin && token) {
    const url = req.nextUrl.clone()
    url.pathname = '/admin/dashboard'
    return NextResponse.redirect(url)
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/login', '/admin/:path*']
}



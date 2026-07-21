"use server"
import { cookies } from 'next/headers'

export async function saveToken(access: string) {
  (await cookies()).set('access_token', access, {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production',
    path: '/',
    maxAge: 60 * 60 * 24
  })
}

export async function logout() {
  (await cookies()).delete('access_token')
}

export async function getToken() {
  return (await cookies()).get('access_token')?.value || '';
}



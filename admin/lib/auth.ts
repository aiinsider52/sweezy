"use server"
import { cookies } from 'next/headers'

export async function saveToken(access: string) {
  cookies().set('access_token', access, {
    httpOnly: true,
    sameSite: 'lax',
    secure: true,
    path: '/',
    maxAge: 60 * 60 * 24
  })
}

export async function logout() {
  cookies().delete('access_token')
}

export async function getToken() {
  return cookies().get('access_token')?.value || ''
}



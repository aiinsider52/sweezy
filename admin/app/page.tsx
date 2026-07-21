import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'

export default async function RootPage() {
  const token = (await cookies()).get('access_token')?.value
  redirect(token ? '/admin/dashboard' : '/login')
}



import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'

export default function RootPage() {
  const token = cookies().get('access_token')?.value
  redirect(token ? '/admin/dashboard' : '/login')
}



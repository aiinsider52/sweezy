import Sidebar from '@/components/Sidebar'
import Header from '@/components/Header'
import { getAdminToken } from '@/lib/admin-auth'
import { redirect } from 'next/navigation'

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  if (!(await getAdminToken())) redirect('/login')

  return (
    <div className="min-h-screen grid grid-cols-[288px_1fr]">
      <Sidebar/>
      <div className="flex flex-col">
        <Header/>
        <main className="container-grid py-8">
          {children}
        </main>
      </div>
    </div>
  )
}



import Sidebar from '@/components/Sidebar'
import Header from '@/components/Header'
import { getAdminToken } from '@/lib/admin-auth'
import { redirect } from 'next/navigation'

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  if (!(await getAdminToken())) redirect('/login')

  return (
    <div className="min-h-screen lg:grid lg:grid-cols-[288px_minmax(0,1fr)]">
      <Sidebar/>
      <div className="flex min-w-0 flex-col">
        <Header/>
        <main className="container-grid py-8">
          {children}
        </main>
      </div>
    </div>
  )
}



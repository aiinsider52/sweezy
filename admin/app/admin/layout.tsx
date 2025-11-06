import Sidebar from '@/components/Sidebar'
import Header from '@/components/Header'

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen grid grid-cols-[260px_1fr]">
      <Sidebar/>
      <div className="flex flex-col">
        <Header/>
        <main className="container-grid py-6">
          {children}
        </main>
      </div>
    </div>
  )
}



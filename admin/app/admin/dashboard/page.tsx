import Sidebar from '@/components/Sidebar'
import Header from '@/components/Header'
import Card from '@/components/Card'
import { cookies } from 'next/headers'
import dynamic from 'next/dynamic'
const Chart = dynamic(() => import('@/components/Chart'), { ssr: false })

export default async function DashboardPage() {
  // simple KPI calls (using readiness and remote-config as examples)
  const base = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy.onrender.com/api/v1'
  const ready = await fetch(`${base}/ready`, { cache: 'no-store' }).then(r=>r.ok)
  const rc = await fetch(`${base}/remote-config/`, { cache: 'no-store' }).then(r=>r.json()).catch(()=>({}))
  const token = cookies().get('access_token')?.value

  const data = [
    { name: 'Users', value: token ? 1 : 0 },
    { name: 'Guides', value: 50 },
    { name: 'Templates', value: 20 }
  ]
  return (
    <div className="min-h-screen grid grid-cols-[240px_1fr]">
      <Sidebar/>
      <div className="flex flex-col">
        <Header/>
        <main className="container-grid grid gap-4 md:grid-cols-2">
          <Card title="Status">{ready ? 'Backend ready' : 'Backend not ready'}</Card>
          <Card title="Version">{rc?.app_version ?? 'n/a'}</Card>
          <Card title="Overview">
            <Chart data={data}/>
          </Card>
        </main>
      </div>
    </div>
  )
}



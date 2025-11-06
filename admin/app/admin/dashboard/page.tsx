import Card from '@/components/Card'
import dynamic from 'next/dynamic'
const Chart = dynamic(() => import('@/components/Chart'), { ssr: false })
import { serverFetch } from '@/lib/server'

export default async function DashboardPage() {
  const ready = await serverFetch('/ready').then(r=>r.ok).catch(()=>false)
  const rc = await serverFetch('/remote-config/').then(r=>r.json()).catch(()=>({}))
  const stats = await serverFetch('/admin/stats').then(r=>r.json()).catch(()=>({ counts: {} }))

  const data = [
    { name: 'Users', value: stats?.counts?.users ?? 0 },
    { name: 'Guides', value: stats?.counts?.guides ?? 0 },
    { name: 'Templates', value: stats?.counts?.templates ?? 0 }
  ]
  return (
    <section className="grid grid-cols-12 gap-6">
      <Card title="Status" className="col-span-12 md:col-span-4">{ready ? 'Backend ready' : 'Backend not ready'}</Card>
      <Card title="Version" className="col-span-12 md:col-span-4">{rc?.app_version ?? 'n/a'}</Card>
      <Card title="Users" className="col-span-12 md:col-span-4">{stats?.counts?.users ?? 0}</Card>
      <div className="col-span-12 lg:col-span-8">
        <Card title="Overview"><Chart data={data}/></Card>
      </div>
    </section>
  )
}



import Card from '@/components/Card'
import ChartContainer from '@/components/ChartContainer'
import { serverFetch } from '@/lib/server'
import { redirect } from 'next/navigation'
import KPI from '@/components/KPI'
import GuidesList from '@/components/admin/GuidesList'

export default async function GuidesPage() {
  const statsRes = await serverFetch('/admin/stats').catch(()=>null)
  if (!statsRes) return <Card>Failed to load</Card>
  if (statsRes.status === 401 || statsRes.status === 403) redirect('/login')
  const stats = await statsRes.json().catch(()=>({ counts: {} }))

  const data = [
    { name: 'Guides', value: stats?.counts?.guides ?? 0 },
    { name: 'Templates', value: stats?.counts?.templates ?? 0 }
  ]

  return (
    <section className="space-y-8">
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        <KPI title="Guides" value={stats?.counts?.guides ?? 0} icon="guides" delta={2}/>
        <KPI title="Templates" value={stats?.counts?.templates ?? 0} icon="templates" delta={1}/>
        <KPI title="Users" value={stats?.counts?.users ?? 0} icon="users" delta={5}/>
        <KPI title="Server" value={'Ready'} icon="server" delta={0}/>
      </div>
      <Card title="Content Overview">
        <ChartContainer data={data} />
      </Card>
      <Card title="Guides">
        <GuidesList/>
      </Card>
    </section>
  )
}


import Card from '@/components/Card'
import ChartContainer from '@/components/ChartContainer'
import { serverFetch } from '@/lib/server'
import KPI from '@/components/KPI'
import { serverFetch as api } from '@/lib/server'

export default async function DashboardPage() {
  const [statsRes, activityRes] = await Promise.all([
    api('/admin/stats').catch(()=>null),
    api('/admin/activity').catch(()=>null)
  ])
  if (!statsRes) {
    return (
      <section className="grid grid-cols-12 gap-6">
        <Card title="Status" className="col-span-12">Failed to load stats.</Card>
      </section>
    )
  }
  const stats = await statsRes.json().catch(()=>({ counts: {}, app_version: 'n/a' }))
  const activity = activityRes && activityRes.ok ? await activityRes.json().catch(()=>null) : null
  const ready = true

  const data = [
    { name: 'Users', value: stats?.counts?.users ?? 0 },
    { name: 'Guides', value: stats?.counts?.guides ?? 0 },
    { name: 'Templates', value: stats?.counts?.templates ?? 0 }
  ]
  return (
    <section className="space-y-8">
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 items-stretch">
        <KPI title="Users" value={stats?.counts?.users ?? 0} icon="users" delta={5} className="h-full"/>
        <KPI title="Guides" value={stats?.counts?.guides ?? 0} icon="guides" delta={2} className="h-full"/>
        <KPI title="Templates" value={stats?.counts?.templates ?? 0} icon="templates" delta={1} className="h-full"/>
        <KPI title="Server" value={ready ? 'Ready' : 'Down'} icon="server" delta={0} className="h-full"/>
      </div>
      <Card title="Overview">
        <ChartContainer data={data}/>
      </Card>
      <Card title="Recent Activity">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 text-sm">
          {(activity?.users ?? []).map((u:any) => (
            <div key={`u-${u.id}`} className="glass px-3 py-2 rounded-lg">User: {u.email} — {u.created_at?.slice(0,16).replace('T',' ')}</div>
          ))}
          {(activity?.guides ?? []).map((g:any) => (
            <div key={`g-${g.id}`} className="glass px-3 py-2 rounded-lg">Guide: {g.id}</div>
          ))}
          {(activity?.templates ?? []).map((t:any) => (
            <div key={`t-${t.id}`} className="glass px-3 py-2 rounded-lg">Template: {t.id}</div>
          ))}
        </div>
      </Card>
    </section>
  )
}


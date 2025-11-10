import Card from '@/components/Card'
import { serverFetch } from '@/lib/server'
import NewsList from '@/components/admin/NewsList'

export default async function NewsPage() {
  const statsRes = await serverFetch('/admin/stats').catch(() => null)
  const stats = statsRes && statsRes.ok ? await statsRes.json().catch(() => ({ counts: {} })) : { counts: {} }

  return (
    <section className="space-y-8">
      {/* KPIs removed temporarily to isolate runtime error */}
      <Card title="News">
        <NewsList />
      </Card>
    </section>
  )
}



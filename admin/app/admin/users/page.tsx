import DataTable from '@/components/DataTable'
import Card from '@/components/Card'
import { serverFetch } from '@/lib/server'
import CreateUserDialog from '@/components/admin/CreateUserDialog'
import KPI from '@/components/KPI'
import Link from 'next/link'
import UserAudienceExport from '@/components/admin/UserAudienceExport'

type SearchParams = Promise<Record<string, string | string[] | undefined>>

export default async function UsersPage({ searchParams }: { searchParams: SearchParams }) {
  const raw = await searchParams
  const value = (key: string) => typeof raw[key] === 'string' ? raw[key] as string : ''
  const page = Math.max(1, Number(value('page')) || 1)
  const query = new URLSearchParams({ page: String(page), page_size: '25' })
  for (const key of ['search', 'role', 'status', 'subscription', 'created_from', 'created_to']) {
    if (value(key)) query.set(key, value(key))
  }
  const [res, statsRes] = await Promise.all([
    serverFetch(`/admin/users?${query}`).catch(() => null),
    serverFetch('/admin/users/stats').catch(()=>null)
  ])
  if (!res) {
    return (
      <section className="space-y-4">
        <h1 className="text-xl font-semibold">Users</h1>
        <Card>Failed to load users.</Card>
      </section>
    )
  }
  if (res.status === 401 || res.status === 403) {
    return (
      <section className="space-y-4">
        <Card>Unauthorized. Please login.</Card>
      </section>
    )
  }
  let result: any = { items: [], page, pages: 0, total: 0 }
  try { result = await res.json() } catch {}
  const users = Array.isArray(result) ? result : result.items ?? []
  const stats = statsRes && statsRes.ok ? await statsRes.json().catch(()=>({})) : {}
  const pageUrl = (nextPage: number) => {
    const params = new URLSearchParams(query)
    params.set('page', String(nextPage))
    params.delete('page_size')
    return `/admin/users?${params}`
  }
  return (
    <section className="space-y-8">
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        <KPI title="Total users" value={stats.total ?? result.total ?? 0} icon="users"/>
        <KPI title="Active" value={stats.active ?? 0} icon="users"/>
        <KPI title="Verified" value={stats.verified ?? 0} icon="users"/>
        <KPI title="Premium" value={stats.premium ?? 0} icon="users"/>
      </div>
      <Card>
        <form className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-7 gap-3 mb-4">
          <input name="search" defaultValue={value('search')} placeholder="Search email or ID…" className="glass px-3 py-2 rounded-lg" />
          <select name="role" defaultValue={value('role')} className="glass px-3 py-2 rounded-lg">
            <option value="">All roles</option><option value="admin">Admin</option><option value="editor">Editor</option>
            <option value="translator">Translator</option><option value="viewer">Viewer</option>
          </select>
          <select name="status" defaultValue={value('status')} className="glass px-3 py-2 rounded-lg">
            <option value="">All statuses</option><option value="active">Active</option><option value="inactive">Inactive</option>
          </select>
          <select name="subscription" defaultValue={value('subscription')} className="glass px-3 py-2 rounded-lg">
            <option value="">All subscriptions</option><option value="free">Free</option><option value="trial">Trial</option><option value="premium">Premium</option>
          </select>
          <input aria-label="Created from" name="created_from" type="date" defaultValue={value('created_from')} className="glass px-3 py-2 rounded-lg" />
          <input aria-label="Created to" name="created_to" type="date" defaultValue={value('created_to')} className="glass px-3 py-2 rounded-lg" />
          <button className="glass px-3 py-2 rounded-lg" type="submit">Apply filters</button>
        </form>
        <div className="flex flex-wrap items-center justify-between gap-3 mb-3">
          <span className="text-sm opacity-70">{result.total ?? users.length} users</span>
          <div className="flex gap-2">
            <UserAudienceExport filters={Object.fromEntries(
              ['search', 'role', 'status', 'subscription', 'created_from', 'created_to']
                .filter((key) => value(key))
                .map((key) => [key, value(key)])
            )} />
            <CreateUserDialog/>
          </div>
        </div>
        <DataTable data={users}/>
        <div className="flex items-center justify-between mt-4 text-sm">
          <Link aria-disabled={page <= 1} className={page <= 1 ? 'pointer-events-none opacity-40' : 'glass px-3 py-2 rounded-lg'} href={pageUrl(page - 1)}>Previous</Link>
          <span>Page {page} of {Math.max(1, result.pages ?? 1)}</span>
          <Link aria-disabled={page >= (result.pages ?? 1)} className={page >= (result.pages ?? 1) ? 'pointer-events-none opacity-40' : 'glass px-3 py-2 rounded-lg'} href={pageUrl(page + 1)}>Next</Link>
        </div>
      </Card>
    </section>
  )
}



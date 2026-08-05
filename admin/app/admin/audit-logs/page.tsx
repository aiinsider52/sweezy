import Card from '@/components/Card'
import { serverFetch } from '@/lib/server'

export default async function AuditLogsPage() {
  const res = await serverFetch('/admin/audit-logs').catch(()=>null)
  const data = res && res.ok ? await res.json().catch(()=>[]) : []
  return (
    <section className="space-y-6">
      <Card title="Audit Logs">
        <div className="flex justify-end mb-3">
          <a className="glass px-3 py-2 rounded-lg text-sm" href="/api/admin/audit-logs/export">Export CSV</a>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="text-left opacity-70">
              <tr>
                <th className="py-2 px-3">When</th>
                <th className="py-2 px-3">User</th>
                <th className="py-2 px-3">Action</th>
                <th className="py-2 px-3">Entity</th>
                <th className="py-2 px-3">ID</th>
              </tr>
            </thead>
            <tbody>
              {Array.isArray(data) && data.length > 0 ? data.map((r: any) => (
                <tr key={r.id} className="border-t border-white/10">
                  <td className="py-2 px-3">{new Date(r.created_at).toLocaleString()}</td>
                  <td className="py-2 px-3">{r.user_email}</td>
                  <td className="py-2 px-3">{r.action}</td>
                  <td className="py-2 px-3">{r.entity}</td>
                  <td className="py-2 px-3">{r.entity_id}</td>
                </tr>
              )) : (
                <tr><td className="py-4 px-3 opacity-70" colSpan={5}>No logs yet</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </Card>
    </section>
  )
}



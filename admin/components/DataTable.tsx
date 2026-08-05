"use client"
import Card from './Card'

type User = {
  id: string
  email: string
  is_superuser: boolean
  is_active?: boolean
  email_verified?: boolean
  subscription_status?: string
  role?: string
  created_at: string
}

export default function DataTable({ data }: { data: User[] | any }) {
  const rows: User[] = Array.isArray(data) ? data : []
  return (
    <Card>
      <div className="overflow-x-auto">
        <table className="min-w-full text-sm">
          <thead className="text-left opacity-70">
            <tr>
              <th className="py-2 pr-4">Email</th>
              <th className="py-2 pr-4">Role</th>
              <th className="py-2 pr-4">Status</th>
              <th className="py-2 pr-4">Subscription</th>
              <th className="py-2 pr-4">Created</th>
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 && (<tr><td className="py-4" colSpan={5}>No matching users</td></tr>)}
            {rows.map(u => (
              <tr key={u.id} className="border-t border-white/10">
                <td className="py-2 pr-4">{u.email}</td>
                <td className="py-2 pr-4">
                  <RoleSelect userId={u.id} defaultValue={u.role || (u.is_superuser ? 'admin' : 'viewer')} />
                </td>
                <td className="py-2 pr-4">{u.is_active === false ? 'Inactive' : 'Active'}{u.email_verified ? ' · verified' : ''}</td>
                <td className="py-2 pr-4">{u.subscription_status ?? 'free'}</td>
                <td className="py-2 pr-4">{new Date(u.created_at).toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  )
}

function RoleSelect({ userId, defaultValue }: { userId: string; defaultValue: string }) {
  async function onChange(e: React.ChangeEvent<HTMLSelectElement>) {
    const role = e.target.value
    await fetch(`/api/admin/users/${userId}/role`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ role }) })
  }
  return (
    <select defaultValue={defaultValue} onChange={onChange} className="glass px-2 py-1 rounded-md">
      <option value="admin">admin</option>
      <option value="editor">editor</option>
      <option value="translator">translator</option>
      <option value="viewer">viewer</option>
    </select>
  )
}



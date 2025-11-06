import Sidebar from '@/components/Sidebar'
import Header from '@/components/Header'
import DataTable from '@/components/DataTable'
import Card from '@/components/Card'
import { serverFetch } from '@/lib/server'

export default async function UsersPage() {
  const users = await serverFetch('/admin/users').then(r=>r.json()).catch(()=>[])
  return (
    <section className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold">Users</h1>
        <CreateUserForm/>
      </div>
      <DataTable data={users}/>
    </section>
  )
}

function CreateUserForm() {
  return (
    <form action={async (formData: FormData) => {
      'use server'
      const email = String(formData.get('email') || '')
      const password = String(formData.get('password') || '')
      await fetch(`${process.env.NEXT_PUBLIC_API_URL}/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      })
    }} className="glass p-2 flex items-center gap-2">
      <input className="bg-transparent px-2 py-1 outline-none" name="email" placeholder="email" />
      <input className="bg-transparent px-2 py-1 outline-none" type="password" name="password" placeholder="password" />
      <button className="glass px-3 py-1">Create</button>
    </form>
  )
}



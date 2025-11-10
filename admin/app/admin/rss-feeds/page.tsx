import { serverFetch } from '@/lib/server'
import Card from '@/components/Card'
import UIInput from '@/components/ui/input'
import UISelect from '@/components/ui/select'
import Button from '@/components/ui/button'
import { revalidatePath } from 'next/cache'

async function getFeeds() {
  const res = await serverFetch('/admin/rss-feeds').catch(()=>null)
  if (!res || !res.ok) return []
  return res.json().catch(()=>[])
}

export default async function RSSFeedsPage() {
  const feeds = await getFeeds()
  return (
    <section className="space-y-8">
      <Card title="RSS Feeds">
        <div className="mb-4">
          <CreateFeedForm />
        </div>
        <div className="overflow-x-auto rounded-xl border border-white/10 bg-white/5 backdrop-blur-md">
          <table className="min-w-full text-sm">
            <thead className="text-left opacity-70 border-b border-white/10">
              <tr>
                <th className="py-3 px-4">URL</th>
                <th className="py-3 px-4">Lang</th>
                <th className="py-3 px-4">Status</th>
                <th className="py-3 px-4">Enabled</th>
                <th className="py-3 px-4">Last import</th>
                <th className="py-3 px-4">Actions</th>
              </tr>
            </thead>
            <tbody>
              {feeds.length === 0 ? (
                <tr><td className="py-6 text-center opacity-70" colSpan={6}>No feeds</td></tr>
              ) : feeds.map((f: any) => (
                <tr key={f.id} className="border-t border-white/5">
                  <td className="py-3 px-4">{f.url}</td>
                  <td className="py-3 px-4">{f.language}</td>
                  <td className="py-3 px-4">{f.status}</td>
                  <td className="py-3 px-4">{f.enabled ? 'yes' : 'no'}</td>
                  <td className="py-3 px-4">{f.last_imported_at ? new Date(f.last_imported_at).toLocaleString() : '—'}</td>
                  <td className="py-3 px-4 flex gap-2">
                    <RunNowButton id={f.id} />
                    <ToggleButton id={f.id} enabled={f.enabled} />
                    <DeleteButton id={f.id} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </section>
  )
}

function DeleteButton({ id }: { id: string }) {
  async function action() {
    "use server"
    await serverFetch(`/admin/rss-feeds/${id}`, { method: 'DELETE' })
    revalidatePath('/admin/rss-feeds')
  }
  return <form action={action}><Button className="px-2 py-1 text-red-400">Delete</Button></form>
}

function RunNowButton({ id }: { id: string }) {
  async function action() {
    "use server"
    await serverFetch(`/admin/rss-feeds/${id}/import`, { method: 'POST' })
    revalidatePath('/admin/rss-feeds')
  }
  return <form action={action}><Button className="px-2 py-1">Run now</Button></form>
}

function ToggleButton({ id, enabled }: { id: string, enabled: boolean }) {
  async function action() {
    "use server"
    await serverFetch(`/admin/rss-feeds/${id}`, { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ enabled: !enabled }) })
    revalidatePath('/admin/rss-feeds')
  }
  return <form action={action}><Button className="px-2 py-1">{enabled ? 'Disable' : 'Enable'}</Button></form>
}

function CreateFeedForm() {
  async function action(formData: FormData) {
    "use server"
    const payload = {
      url: String(formData.get('url') || ''),
      language: String(formData.get('language') || 'uk'),
      status: String(formData.get('status') || 'draft'),
      max_items: Number(formData.get('max_items') || 20),
      download_images: Boolean(formData.get('download_images') || false),
    }
    await serverFetch('/admin/rss-feeds', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) })
    revalidatePath('/admin/rss-feeds')
  }
  return (
    <form action={action} className="grid grid-cols-1 md:grid-cols-5 gap-3 items-end">
      <div className="md:col-span-2">
        <div className="text-sm opacity-70 mb-1">Feed URL</div>
        <UIInput name="url" placeholder="https://example.com/feed.xml" />
      </div>
      <div>
        <div className="text-sm opacity-70 mb-1">Language</div>
        <select name="language" className="glass px-3 py-2 rounded-lg">
          <option value="uk">uk</option>
          <option value="ru">ru</option>
          <option value="en">en</option>
        </select>
      </div>
      <div>
        <div className="text-sm opacity-70 mb-1">Status</div>
        <select name="status" className="glass px-3 py-2 rounded-lg">
          <option value="draft">draft</option>
          <option value="published">published</option>
        </select>
      </div>
      <div className="md:col-span-5 flex items-center gap-3">
        <div>
          <div className="text-sm opacity-70 mb-1">Max items</div>
          <UIInput name="max_items" type="number" defaultValue="20" className="w-28" />
        </div>
        <label className="inline-flex items-center gap-2 text-sm opacity-80">
          <input type="checkbox" name="download_images" defaultChecked /> Download images
        </label>
        <Button type="submit" className="ml-auto px-4 py-2">Add feed</Button>
      </div>
    </form>
  )
}



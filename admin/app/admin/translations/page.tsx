import Card from '@/components/Card'
import { serverFetch } from '@/lib/server'
import TranslationEditorDialog from '@/components/admin/TranslationEditorDialog'
import UIButton from '@/components/ui/button'

export default async function TranslationsPage(props: any) {
  const searchParams = await props.searchParams;
  const qs = new URLSearchParams(searchParams as any).toString()
  const res = await serverFetch(`/translations${qs ? `?${qs}` : ''}`).catch(()=>null)
  const data = res && res.ok ? await res.json().catch(()=>[]) : []
  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="text-lg font-semibold">Translations</div>
        <TranslationEditorDialog />
      </div>
      <Card>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="text-left opacity-70">
              <tr>
                <th className="py-2 px-3">Entity</th>
                <th className="py-2 px-3">Entity ID</th>
                <th className="py-2 px-3">Lang</th>
                <th className="py-2 px-3">Status</th>
                <th className="py-2 px-3">Updated</th>
                <th className="py-2 px-3">Actions</th>
              </tr>
            </thead>
            <tbody>
              {Array.isArray(data) && data.length > 0 ? data.map((r: any) => (
                <tr key={r.id} className="border-t border-white/10">
                  <td className="py-2 px-3">{r.entity}</td>
                  <td className="py-2 px-3">{r.entity_id}</td>
                  <td className="py-2 px-3">{r.language}</td>
                  <td className="py-2 px-3">{r.status}</td>
                  <td className="py-2 px-3">{new Date(r.updated_at).toLocaleString()}</td>
                  <td className="py-2 px-3">
                    <form action={`/api/translations/${r.id}/approve`} method="post">
                      <UIButton type="submit" size="sm">Approve</UIButton>
                    </form>
                  </td>
                </tr>
              )) : (
                <tr><td className="py-4 px-3 opacity-70" colSpan={6}>No translations</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </Card>
    </section>
  )
}



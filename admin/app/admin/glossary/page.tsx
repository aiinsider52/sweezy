import Card from '@/components/Card'
import { serverFetch } from '@/lib/server'
import UIInput from '@/components/ui/input'
import UIButton from '@/components/ui/button'

export default async function GlossaryPage(props: any) {
  const searchParams = await props.searchParams;
  const q = searchParams?.q ? `?q=${encodeURIComponent(searchParams.q)}` : ''
  const res = await serverFetch(`/translations/glossary${q}`).catch(()=>null)
  const data = res && res.ok ? await res.json().catch(()=>[]) : []
  return (
    <section className="space-y-6">
      <div className="text-lg font-semibold">Glossary</div>
      <Card>
        <div className="mb-4 flex items-center gap-3">
          <form action="/admin/glossary" className="flex items-center gap-2">
            <UIInput name="q" placeholder="Search term…" defaultValue={searchParams?.q || ''}/>
            <UIButton type="submit">Search</UIButton>
          </form>
          <AddTermForm />
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="text-left opacity-70">
              <tr>
                <th className="py-2 px-3">Term</th>
                <th className="py-2 px-3">uk</th>
                <th className="py-2 px-3">ru</th>
                <th className="py-2 px-3">en</th>
                <th className="py-2 px-3">Actions</th>
              </tr>
            </thead>
            <tbody>
              {Array.isArray(data) && data.length > 0 ? data.map((r: any) => (
                <tr key={r.id} className="border-t border-white/10">
                  <td className="py-2 px-3">{r.term}</td>
                  <td className="py-2 px-3">{r.uk || '—'}</td>
                  <td className="py-2 px-3">{r.ru || '—'}</td>
                  <td className="py-2 px-3">{r.en || '—'}</td>
                  <td className="py-2 px-3">
                    <form action={`/api/translations/glossary/${r.id}`} method="post">
                      <input type="hidden" name="_method" value="DELETE" />
                      <UIButton formAction={async () => {
                        await fetch(`/api/translations/glossary/${r.id}`, { method: 'DELETE' })
                      }} size="sm" variant="destructive">Delete</UIButton>
                    </form>
                  </td>
                </tr>
              )) : (
                <tr><td className="py-4 px-3 opacity-70" colSpan={5}>No terms</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </Card>
    </section>
  )
}

function AddTermForm() {
  async function action(formData: FormData) {
    "use server"
    const payload = {
      term: String(formData.get('term')||''),
      uk: String(formData.get('uk')||''),
      ru: String(formData.get('ru')||''),
      en: String(formData.get('en')||''),
      description: String(formData.get('description')||''),
    }
    await fetch('/api/translations/glossary', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) })
  }
  return (
    <form action={action} className="grid grid-cols-1 md:grid-cols-5 gap-2 items-end">
      <UIInput name="term" placeholder="Term" className="md:col-span-2"/>
      <UIInput name="uk" placeholder="uk" />
      <UIInput name="ru" placeholder="ru" />
      <UIInput name="en" placeholder="en" />
      <UIButton type="submit">Add term</UIButton>
    </form>
  )
}



"use client"
import { useEffect, useMemo, useState } from 'react'
import { Dialog } from '@/components/ui/dialog'
import UIInput from '@/components/ui/input'
import UIButton from '@/components/ui/button'
import MarkdownEditor from '@/components/admin/MarkdownEditor'

type Guide = {
  id?: string
  title: string
  slug: string
  description?: string
  content?: string
  category?: string
  is_published?: boolean
  image_url?: string
  source_url?: string
  source_title?: string
  verified_at?: string
}

export default function GuideEditorDialog({ guide, onSaved }: { guide?: Guide; onSaved?: () => void }) {
  const [open, setOpen] = useState(false)
  const [form, setForm] = useState<Guide>({ title: '', slug: '', description: '', content: '', category: '', is_published: true })
  const [saving, setSaving] = useState(false)

  useEffect(() => { if (guide) setForm(guide) }, [guide])

  async function save() {
    setSaving(true)
    try {
      const method = guide?.id ? 'PUT' : 'POST'
      const url = guide?.id ? `/api/guides/${guide.id}` : '/api/guides'
      const res = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(form) })
      if (!res.ok) throw new Error(await res.text())
      setOpen(false)
      onSaved?.()
    } finally {
      setSaving(false)
    }
  }

  function renderMarkdown(md?: string) {
    if (!md) return ''
    let html = md
      .replace(/^###\s(.+)$/gim, '<h3>$1</h3>')
      .replace(/^##\s(.+)$/gim, '<h2>$1</h2>')
      .replace(/^#\s(.+)$/gim, '<h1>$1</h1>')
      .replace(/\*\*(.+?)\*\*/gim, '<strong>$1</strong>')
      .replace(/\*(.+?)\*/gim, '<em>$1</em>')
      .replace(/\n/g, '<br/>')
    return html
  }

  const [categories, setCategories] = useState<string[]>([])
  useEffect(() => { (async ()=>{
    const fallback = [
      'documents','housing','insurance','work','finance','education','healthcare','legal','emergency','integration','transport','banking'
    ]
    try {
      const res = await fetch('/api/admin/categories/guides')
      if (!res.ok) { setCategories(fallback); return }
      const j = await res.json().catch(()=>({}))
      setCategories(Array.isArray(j.categories) && j.categories.length ? j.categories : fallback)
    } catch { setCategories(fallback) }
  })() }, [])

  return (
    <div>
      <UIButton onClick={() => setOpen(true)}>{guide ? 'Edit' : 'Create Guide'}</UIButton>
      <Dialog open={open} onClose={() => setOpen(false)} size="xl">
        <div className="text-lg font-medium mb-3">{guide ? 'Edit Guide' : 'Create Guide'}</div>
        <div className="space-y-3">
          <UIInput placeholder="Title" value={form.title} onChange={e=>setForm({ ...form, title: e.target.value })} />
          <UIInput placeholder="Slug" value={form.slug} onChange={e=>setForm({ ...form, slug: e.target.value })} />
          <select className="glass w-full px-3 py-2" value={form.category||''} onChange={e=>setForm({...form, category:e.target.value})}>
            <option value="">Select category…</option>
            {categories.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
          <UIInput placeholder="Description" value={form.description} onChange={e=>setForm({ ...form, description: e.target.value })} />
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <UIInput placeholder="Official source URL" value={form.source_url ?? ''} onChange={e=>setForm({ ...form, source_url: e.target.value })} />
            <UIInput placeholder="Source title (e.g. ch.ch)" value={form.source_title ?? ''} onChange={e=>setForm({ ...form, source_title: e.target.value })} />
          </div>
          <label className="text-sm opacity-80">
            Last verified
            <UIInput type="date" value={form.verified_at?.slice(0, 10) ?? ''} onChange={e=>setForm({ ...form, verified_at: e.target.value ? `${e.target.value}T00:00:00Z` : undefined })} />
          </label>
          <MarkdownEditor value={form.content ?? ''} onChange={(v)=>setForm({...form, content: v})} />
          <div className="space-y-2">
            {form.image_url && (<img src={form.image_url} alt="preview" className="w-full h-40 object-cover rounded-lg" />)}
            <input type="file" accept="image/*" onChange={async e=>{
              const file = e.target.files?.[0]
              if (!file) return
              const fd = new FormData()
              fd.append('file', file)
              const res = await fetch('/api/media/upload', { method: 'POST', body: fd })
              const j = await res.json().catch(()=>null)
              if (j?.url) setForm({ ...form, image_url: j.url })
            }} />
          </div>
          <div className="flex items-center gap-2">
            <input id="pub" type="checkbox" checked={!!form.is_published} onChange={e=>setForm({ ...form, is_published: e.target.checked })} />
            <label htmlFor="pub" className="text-sm opacity-80">Published</label>
          </div>
          <UIButton onClick={save} disabled={saving}>{saving ? 'Saving…' : 'Save'}</UIButton>
        </div>
      </Dialog>
    </div>
  )
}


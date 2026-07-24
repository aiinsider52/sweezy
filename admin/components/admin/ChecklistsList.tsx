"use client"
import { useCallback, useEffect, useMemo, useState } from 'react'
import UIButton from '@/components/ui/button'
import UISelect from '@/components/ui/select'
import UIInput from '@/components/ui/input'
import ChecklistEditorDialog from './ChecklistEditorDialog'

type Checklist = { id: string; title: string; description?: string; items: string[]; is_published?: boolean; status?: string }

export default function ChecklistsList() {
  const [items, setItems] = useState<Checklist[]>([])
  const [loading, setLoading] = useState(true)
  const [q, setQ] = useState('')
  const [editing, setEditing] = useState<Checklist | undefined>(undefined)
  const [status, setStatus] = useState<'all'|'published'|'draft'>('all')

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const params = new URLSearchParams()
      params.set('include_drafts','true')
      if (status !== 'all') params.set('status', status)
      const res = await fetch(`/api/checklists?${params.toString()}`)
      if (!res.ok) { setItems([]); return }
      const data = await res.json().catch(()=>[])
      setItems(Array.isArray(data) ? data : [])
    } catch { setItems([]) } finally { setLoading(false) }
  }, [status])
  useEffect(() => { void load() }, [load])

  const filtered = useMemo(() => items.filter(t => (t.title + (t.description||'')).toLowerCase().includes(q.toLowerCase())), [items, q])

  return (
    <div className="space-y-3">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div className="flex items-center gap-2">
          <UIInput placeholder="Search checklists…" value={q} onChange={e=>setQ(e.target.value)} className="w-full sm:max-w-xs" />
          <span className="text-sm opacity-70">Status</span>
          <UISelect className="min-w-[120px]" value={status} onChange={(v)=>setStatus(v as any)} options={[{value:"all",label:"all"},{value:"published",label:"published"},{value:"draft",label:"draft"}]} />
        </div>
        <div className="flex items-center gap-2">
          <input id="import-checklists" type="file" accept="application/json" className="hidden" onChange={async e=>{
            const file = e.target.files?.[0]; if (!file) return
            const text = await file.text();
            try { const items = JSON.parse(text); await fetch('/api/admin/import/checklists', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ items }) }); await load() } catch {}
          }}/>
          <UIButton size="sm" onClick={()=>document.getElementById('import-checklists')?.click()}>Import JSON</UIButton>
          <ChecklistEditorDialog onSaved={load} />
        </div>
      </div>
      {loading ? (
        <div className="opacity-70">Loading…</div>
      ) : filtered.length === 0 ? (
        <div className="glass p-6 rounded-xl text-center opacity-80">No checklists yet.</div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {filtered.map(t => (
            <div key={t.id} className="glass p-4 rounded-xl flex flex-col gap-2">
              <div className="text-lg font-medium">{t.title}</div>
              <div className="text-xs opacity-60">{t.description}</div>
              <div className="text-xs opacity-60">Status: {(t as any).status || (t.is_published ? 'published' : 'draft')}</div>
              <div className="mt-auto flex items-center justify-between gap-2">
                <UIButton variant="ghost" size="sm" onClick={() => setEditing(t)}>Edit</UIButton>
                <UIButton size="sm" onClick={async () => {
                  const next = ((t as any).status === 'published' || t.is_published) ? 'draft' : 'published'
                  await fetch(`/api/checklists/${t.id}`, { method: 'PUT', headers: {'Content-Type':'application/json'}, body: JSON.stringify({ status: next }) })
                  await load()
                }}>{((t as any).status === 'published' || t.is_published) ? 'Unpublish' : 'Publish'}</UIButton>
                <UIButton variant="destructive" size="sm" onClick={async () => { if (!confirm('Delete checklist?')) return; await fetch(`/api/checklists/${t.id}`, { method: 'DELETE' }); await load() }}>Delete</UIButton>
              </div>
            </div>
          ))}
        </div>
      )}
      {editing && <ChecklistEditorDialog item={editing} onSaved={() => { setEditing(undefined); load() }} />}
    </div>
  )
}


"use client"
import { useEffect, useState } from 'react'
import { Dialog } from '@/components/ui/dialog'
import UIInput from '@/components/ui/input'
import UIButton from '@/components/ui/button'

type Checklist = { id?: string; title: string; description?: string; items: string[]; is_published?: boolean }
type Step = { id: string; title: string; description?: string }

export default function ChecklistEditorDialog({ item, onSaved }: { item?: Checklist; onSaved?: () => void }) {
  const [open, setOpen] = useState(false)
  const [form, setForm] = useState<Checklist>({ title: '', description: '', items: [], is_published: true })
  const [steps, setSteps] = useState<Step[]>([])
  const [saving, setSaving] = useState(false)
  const [dragIndex, setDragIndex] = useState<number | null>(null)
  useEffect(() => {
    if (item) {
      setForm(item)
      setSteps(item.items.map((t, i) => ({ id: `${i}-${t.slice(0,10)}`, title: t })))
    } else {
      setSteps([{ id: 's-1', title: '' }])
    }
  }, [item])

  async function save() {
    setSaving(true)
    try {
      const method = item?.id ? 'PUT' : 'POST'
      const url = item?.id ? `/api/checklists/${item.id}` : '/api/checklists'
      const payload = { ...form, items: steps.map(s => s.title.trim()).filter(Boolean) }
      const res = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) })
      if (!res.ok) throw new Error(await res.text())
      setOpen(false)
      onSaved?.()
    } finally { setSaving(false) }
  }

  return (
    <div>
      <UIButton onClick={() => setOpen(true)}>{item ? 'Edit' : 'Create Checklist'}</UIButton>
      <Dialog open={open} onClose={() => setOpen(false)} size="xl">
        <div className="text-lg font-medium mb-4">{item ? 'Edit Checklist' : 'Create Checklist'}</div>
        <div className="grid grid-cols-1 gap-4">
          <UIInput placeholder="Title" value={form.title} onChange={e=>setForm({...form, title:e.target.value})} />
          <UIInput placeholder="Description" value={form.description} onChange={e=>setForm({...form, description:e.target.value})} />
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="text-sm opacity-70">Steps</div>
              <UIButton size="sm" onClick={()=>setSteps(s=>[...s, { id: `s-${s.length+1}`, title: '' }])}>Add Step</UIButton>
            </div>
            <div className="space-y-2 max-h-[50vh] overflow-auto pr-1">
              {steps.map((s, idx) => (
                <div
                  key={s.id}
                  className="glass p-3 rounded-lg flex items-center gap-2"
                  draggable
                  onDragStart={() => setDragIndex(idx)}
                  onDragOver={e => e.preventDefault()}
                  onDrop={() => {
                    if (dragIndex === null || dragIndex === idx) return
                    setSteps(prev => {
                      const next = [...prev]
                      const [moved] = next.splice(dragIndex, 1)
                      next.splice(idx, 0, moved)
                      return next
                    })
                    setDragIndex(null)
                  }}
                >
                  <div className="text-xs opacity-60 w-6">{idx+1}.</div>
                  <UIInput className="flex-1" placeholder="Step title" value={s.title} onChange={e=>setSteps(prev=>prev.map(x=>x.id===s.id?{...x, title:e.target.value}:x))} />
                  <div className="flex items-center gap-2">
                    <UIButton size="sm" variant="ghost" onClick={()=>{
                      setSteps(prev => {
                        const next = [...prev]
                        if (idx>0) { const [m]=next.splice(idx,1); next.splice(idx-1,0,m) }
                        return next
                      })
                    }}>↑</UIButton>
                    <UIButton size="sm" variant="ghost" onClick={()=>{
                      setSteps(prev => {
                        const next = [...prev]
                        if (idx<next.length-1) { const [m]=next.splice(idx,1); next.splice(idx+1,0,m) }
                        return next
                      })
                    }}>↓</UIButton>
                    <UIButton size="sm" variant="destructive" onClick={()=>setSteps(prev=>prev.filter(x=>x.id!==s.id))}>Delete</UIButton>
                  </div>
                </div>
              ))}
            </div>
          </div>
          <div className="flex items-center gap-2">
            <input id="cpub" type="checkbox" checked={!!form.is_published} onChange={e=>setForm({ ...form, is_published: e.target.checked })} />
            <label htmlFor="cpub" className="text-sm opacity-80">Published</label>
          </div>
          <div className="text-right"><UIButton onClick={save} disabled={saving}>{saving ? 'Saving…' : 'Save'}</UIButton></div>
        </div>
      </Dialog>
    </div>
  )
}



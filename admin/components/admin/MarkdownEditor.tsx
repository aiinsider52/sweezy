"use client"
import { useEffect, useMemo, useRef, useState } from 'react'
import UIButton from '@/components/ui/button'
import DOMPurify from 'dompurify'
import { marked } from 'marked'

type Props = {
  value: string
  onChange: (next: string) => void
  placeholder?: string
}

export default function MarkdownEditor({ value, onChange, placeholder }: Props) {
  const [showPreview, setShowPreview] = useState(true)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  function insert(before: string, after: string = '') {
    const el = textareaRef.current
    if (!el) return
    const start = el.selectionStart
    const end = el.selectionEnd
    const selected = value.slice(start, end)
    const next = value.slice(0, start) + before + selected + after + value.slice(end)
    onChange(next)
    requestAnimationFrame(() => {
      el.focus()
      const pos = start + before.length + selected.length + after.length
      el.setSelectionRange(pos, pos)
    })
  }

  async function uploadImage(file: File) {
    const fd = new FormData()
    fd.append('file', file)
    const res = await fetch('/api/media/upload', { method: 'POST', body: fd })
    const j = await res.json().catch(()=>null)
    if (j?.url) insert(`![image](${j.url})`)
  }

  function onDrop(e: React.DragEvent) {
    e.preventDefault()
    const file = e.dataTransfer.files?.[0]
    if (file) uploadImage(file)
  }

  const previewHtml = useMemo(() => {
    if (!value) return ''
    const rendered = marked.parse(value, { async: false }) as string
    return DOMPurify.sanitize(rendered, {
      USE_PROFILES: { html: true },
      FORBID_TAGS: ['style', 'iframe', 'object', 'embed'],
      FORBID_ATTR: ['style'],
    })
  }, [value])

  return (
    <div className="space-y-2">
      <div className="flex flex-wrap items-center gap-2">
        <UIButton size="sm" variant="ghost" onClick={() => insert('# ', '')}>H1</UIButton>
        <UIButton size="sm" variant="ghost" onClick={() => insert('## ', '')}>H2</UIButton>
        <UIButton size="sm" variant="ghost" onClick={() => insert('### ', '')}>H3</UIButton>
        <UIButton size="sm" variant="ghost" onClick={() => insert('**', '**')}>Bold</UIButton>
        <UIButton size="sm" variant="ghost" onClick={() => insert('*', '*')}>Italic</UIButton>
        <UIButton size="sm" variant="ghost" onClick={() => insert('\n- ', '')}>List</UIButton>
        <UIButton size="sm" variant="ghost" onClick={() => insert('> ', '')}>Quote</UIButton>
        <UIButton size="sm" variant="ghost" onClick={() => insert('`', '`')}>Code</UIButton>
        <label className="glass px-3 py-1.5 rounded-lg cursor-pointer text-sm">
          Image
          <input type="file" accept="image/*" className="hidden" onChange={e=>{ const f=e.target.files?.[0]; if (f) uploadImage(f) }} />
        </label>
        <div className="ml-auto">
          <UIButton size="sm" variant="ghost" onClick={() => setShowPreview(v=>!v)}>{showPreview ? 'Hide preview' : 'Show preview'}</UIButton>
        </div>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        <textarea
          ref={textareaRef}
          className="glass w-full px-3 py-2 min-h-[220px] font-mono text-sm"
          placeholder={placeholder || 'Write markdown…'}
          value={value}
          onChange={e=>onChange(e.target.value)}
          onDrop={onDrop}
          onKeyDown={(e)=>{
            if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'b') { e.preventDefault(); insert('**','**') }
            if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'i') { e.preventDefault(); insert('*','*') }
            if ((e.metaKey || e.ctrlKey) && e.key === '1') { e.preventDefault(); insert('# ', '') }
            if ((e.metaKey || e.ctrlKey) && e.key === '2') { e.preventDefault(); insert('## ', '') }
            if ((e.metaKey || e.ctrlKey) && e.key === '3') { e.preventDefault(); insert('### ', '') }
          }}
        />
        {showPreview && (
          <div className="glass w-full px-4 py-3 min-h-[220px] md-preview"
               dangerouslySetInnerHTML={{ __html: previewHtml }} />
        )}
      </div>
    </div>
  )
}



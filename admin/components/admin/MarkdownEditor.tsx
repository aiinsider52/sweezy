"use client"
import { useEffect, useMemo, useRef, useState } from 'react'
import UIButton from '@/components/ui/button'

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

  function renderMarkdown(md?: string) {
    if (!md) return ''
    let html = md
      .replace(/^######\s(.+)$/gim, '<h6>$1</h6>')
      .replace(/^#####\s(.+)$/gim, '<h5>$1</h5>')
      .replace(/^####\s(.+)$/gim, '<h4>$1</h4>')
      .replace(/^###\s(.+)$/gim, '<h3>$1</h3>')
      .replace(/^##\s(.+)$/gim, '<h2>$1</h2>')
      .replace(/^#\s(.+)$/gim, '<h1>$1</h1>')
      .replace(/^>\s(.+)$/gim, '<blockquote>$1</blockquote>')
      .replace(/\*\*(.+?)\*\*/gim, '<strong>$1</strong>')
      .replace(/\*(.+?)\*/gim, '<em>$1</em>')
      .replace(/`([^`]+)`/gim, '<code>$1</code>')
      .replace(/!\[(.*?)\]\((.*?)\)/gim, '<img alt="$1" src="$2" />')
      .replace(/\[(.*?)\]\((.*?)\)/gim, '<a href="$2" target="_blank" rel="noreferrer">$1<\/a>')
      .replace(/\n\-\s(.+)/gim, '<ul><li>$1</li></ul>')
      .replace(/\n/g, '<br/>')
    // merge adjacent <ul>
    html = html.replace(/<\/ul><ul>/g, '')
    return html
  }

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
               dangerouslySetInnerHTML={{ __html: renderMarkdown(value) }} />
        )}
      </div>
    </div>
  )
}



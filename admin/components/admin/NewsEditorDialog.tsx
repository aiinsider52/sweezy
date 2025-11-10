"use client"
import { useEffect, useState } from 'react'
import { Dialog } from '@/components/ui/dialog'
import Button from '@/components/ui/button'
import UIInput from '@/components/ui/input'
import UISelect from '@/components/ui/select'
import { useQueryClient } from '@tanstack/react-query'
import { toast } from 'react-hot-toast'
import { News } from '@/lib/types'
import { API_URL } from '@/lib/api'

export default function NewsEditorDialog({ news, trigger }: { news?: News; trigger?: React.ReactNode }) {
  const [isOpen, setIsOpen] = useState(false)
  const [title, setTitle] = useState(news?.title ?? '')
  const [summary, setSummary] = useState(news?.summary ?? '')
  const [url, setUrl] = useState(news?.url ?? '')
  const [source, setSource] = useState(news?.source ?? 'Sweezy')
  const [language, setLanguage] = useState(news?.language ?? 'uk')
  const [publishedAt, setPublishedAt] = useState<string>(news?.published_at ?? new Date().toISOString())
  const [imageUrl, setImageUrl] = useState(news?.image_url ?? '')
  const [loading, setLoading] = useState(false)
  const qc = useQueryClient()
  const API_ORIGIN = (()=>{ try { return new URL(API_URL).origin } catch { return '' } })()

  useEffect(() => {
    if (isOpen) {
      setTitle(news?.title ?? '')
      setSummary(news?.summary ?? '')
      setUrl(news?.url ?? '')
      setSource(news?.source ?? 'Sweezy')
      setLanguage(news?.language ?? 'uk')
      setPublishedAt(news?.published_at ?? new Date().toISOString())
      setImageUrl(news?.image_url ?? '')
    }
  }, [isOpen, news])

  const publishedAtInput = (() => {
    try { return new Date(publishedAt).toISOString().slice(0,16) } catch { return new Date().toISOString().slice(0,16) }
  })()

  const submit = async () => {
    setLoading(true)
    try {
      const payload = { title, summary, url, source, language, published_at: publishedAt, image_url: imageUrl || undefined }
      const res = await fetch(news ? `/api/news/${news.id}` : `/api/news`, {
        method: news ? 'PUT' : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      })
      if (!res.ok) throw new Error(await res.text())
      toast.success(news ? 'News updated' : 'News created')
      setIsOpen(false)
      qc.invalidateQueries({ queryKey: ['news'] })
    } catch (e: any) {
      toast.error(e?.message || 'Failed to save news')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div>
      {trigger ? (
        <span onClick={() => setIsOpen(true)}>{trigger}</span>
      ) : (
        <Button onClick={() => setIsOpen(true)}>Create News</Button>
      )}
      <Dialog open={isOpen} onClose={() => setIsOpen(false)} size="xl">
        <div className="text-lg font-medium mb-3">{news ? 'Edit News' : 'Create News'}</div>
        <div className="text-sm opacity-70 mb-4">Manage a news item that appears in What’s New.</div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="space-y-3">
            <div className="space-y-1">
              <div className="text-sm opacity-70">Title</div>
              <UIInput placeholder="Short, catchy headline" value={title} onChange={e=>setTitle(e.target.value)} />
              <div className="text-xs opacity-60">Будет отображаться крупным шрифтом.</div>
            </div>
            <div className="space-y-1">
              <div className="text-sm opacity-70">Summary</div>
              <textarea
                className="glass w-full px-3 py-2 min-h-[88px]"
                placeholder="Короткий тизер на 1–2 предложения"
                value={summary}
                onChange={e=>setSummary(e.target.value)}
              />
            </div>
            <div className="space-y-1">
              <div className="text-sm opacity-70">Link URL</div>
              <UIInput placeholder="https://..." value={url} onChange={e=>setUrl(e.target.value)} />
              <div className="text-xs opacity-60">По нажатию в приложении откроется эта ссылка.</div>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
              <div className="space-y-1">
                <div className="text-sm opacity-70">Source</div>
                <UIInput placeholder="Sweezy" value={source} onChange={e=>setSource(e.target.value)} />
              </div>
              <div className="space-y-1">
                <div className="text-sm opacity-70">Language</div>
                <UISelect
                  value={language}
                  onChange={setLanguage}
                  options={[
                    { value: 'uk', label: 'uk' },
                    { value: 'en', label: 'en' },
                    { value: 'ru', label: 'ru' },
                  ]}
                />
              </div>
              <div className="space-y-1">
                <div className="text-sm opacity-70">Published at</div>
                <input
                  type="datetime-local"
                  className="glass w-full px-3 py-2"
                  value={publishedAtInput}
                  onChange={e=>setPublishedAt(new Date(e.target.value).toISOString())}
                />
              </div>
            </div>
            <div className="space-y-1">
              <div className="text-sm opacity-70">Image URL</div>
              <UIInput placeholder="https://.../image.jpg" value={imageUrl} onChange={e=>setImageUrl(e.target.value)} />
              <div className="text-xs opacity-60">Опционально. Если указать, превью будет с картинкой.</div>
            </div>
            <div
              className="mt-2 rounded-lg border border-dashed border-white/20 p-4 text-sm opacity-80 text-center"
              onDragOver={(e)=>e.preventDefault()}
              onDrop={async (e)=>{
                e.preventDefault()
                const file = e.dataTransfer.files?.[0]
                if (!file) return
                const fd = new FormData()
                fd.append('file', file)
                const res = await fetch('/api/media/upload', { method: 'POST', body: fd })
                const j = await res.json().catch(()=>null)
                if (j?.url) setImageUrl(j.url.startsWith('/media') && API_ORIGIN ? `${API_ORIGIN}${j.url}` : j.url)
              }}
            >
              Перетащи сюда изображение или
              <label className="ml-1 underline cursor-pointer">
                выбери файл
                <input
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={async e=>{
                    const f = e.target.files?.[0]; if (!f) return
                    const fd = new FormData(); fd.append('file', f)
                    const res = await fetch('/api/media/upload', { method: 'POST', body: fd })
                    const j = await res.json().catch(()=>null)
                    if (j?.url) setImageUrl(j.url.startsWith('/media') && API_ORIGIN ? `${API_ORIGIN}${j.url}` : j.url)
                  }}
                />
              </label>
            </div>
            <div className="text-right">
              <Button onClick={submit} disabled={loading || !title || !url}>{loading ? 'Saving…' : 'Save'}</Button>
            </div>
          </div>
          <div className="space-y-2">
            <div className="text-sm opacity-70">Preview (как в приложении)</div>
            <div className="glass rounded-xl overflow-hidden">
              {imageUrl ? (
                <img src={imageUrl} alt="cover" className="w-full h-40 object-cover" />
              ) : (
                <div className="w-full h-40 flex items-center justify-center text-sm opacity-60">No image</div>
              )}
              <div className="p-4 space-y-2">
                <div className="text-xs opacity-60">
                  {source} • {new Date(publishedAt).toLocaleDateString()}
                </div>
                <div className="text-lg font-semibold">{title || 'Заголовок новости'}</div>
                {summary && <div className="opacity-80 text-sm">{summary}</div>}
                <a
                  href={url || '#'}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center gap-2 text-cyan-300 hover:text-cyan-200 text-sm"
                >
                  Открыть ссылку
                </a>
              </div>
            </div>
          </div>
        </div>
      </Dialog>
    </div>
  )
}

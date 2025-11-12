'use client'
import { useEffect, useMemo, useRef, useState } from 'react'
import Card from '@/components/Card'
import { useRouter } from 'next/navigation'

type JobItem = {
  id: string
  source: 'indeed' | 'rav' | string
  title: string
  company?: string
  location?: string
  canton?: string
  url: string
  posted_at?: string
  employment_type?: string
  salary?: string
  snippet?: string
}

const CANTONS = ['AG','AI','AR','BE','BL','BS','FR','GE','GL','GR','JU','LU','NE','NW','OW','SG','SH','SO','SZ','TG','TI','UR','VD','VS','ZG','ZH']

const dict: Record<string, Record<string, string>> = {
  en: {
    title: 'Job Finder',
    searchPlaceholder: 'Keyword (e.g., nurse, Java, warehouse)',
    canton: 'Canton',
    search: 'Search',
    results: 'Results',
    favorite: 'Favorite',
    unfavorite: 'Unfavorite',
    notify: 'Notify about new jobs',
    apply: 'AI: draft application',
    copied: 'Copied to clipboard',
    empty: 'No jobs found. Try different keywords.',
  },
  de: {
    title: 'Jobsuche',
    searchPlaceholder: 'Stichwort (z. B. Pflege, Java, Lager)',
    canton: 'Kanton',
    search: 'Suchen',
    results: 'Ergebnisse',
    favorite: 'Merken',
    unfavorite: 'Entfernen',
    notify: 'Benachrichtigungen über neue Stellen',
    apply: 'KI: Bewerbung erstellen',
    copied: 'In die Zwischenablage kopiert',
    empty: 'Keine Stellen gefunden. Andere Suchbegriffe versuchen.',
  },
  ru: {
    title: 'Поиск работы',
    searchPlaceholder: 'Ключевое слово (например, медсестра, Java, склад)',
    canton: 'Кантон',
    search: 'Искать',
    results: 'Результаты',
    favorite: 'В избранное',
    unfavorite: 'Убрать',
    notify: 'Уведомлять о новых вакансиях',
    apply: 'ИИ: отклик на вакансию',
    copied: 'Скопировано в буфер',
    empty: 'Вакансии не найдены. Попробуйте другой запрос.',
  },
  uk: {
    title: 'Пошук роботи',
    searchPlaceholder: 'Ключове слово (напр., медсестра, Java, склад)',
    canton: 'Кантон',
    search: 'Шукати',
    results: 'Результати',
    favorite: 'В обране',
    unfavorite: 'Прибрати',
    notify: 'Сповіщати про нові вакансії',
    apply: 'ШІ: відгук на вакансію',
    copied: 'Скопійовано',
    empty: 'Вакансій не знайдено. Спробуйте інший запит.',
  },
}

function useI18n() {
  // Avoid hydration mismatch: render EN on server and first client paint,
  // then switch to user language after mount.
  const [code, setCode] = useState<'en' | 'de' | 'ru' | 'uk'>('en')
  useEffect(() => {
    try {
      const stored = typeof window !== 'undefined' ? localStorage.getItem('lang') : null
      const nav = typeof navigator !== 'undefined' ? navigator.language.split('-')[0] : 'en'
      const detected = ((stored || nav || 'en').toLowerCase().slice(0,2)) as 'en' | 'de' | 'ru' | 'uk'
      if (dict[detected]) setCode(detected)
    } catch {}
  }, [])
  return (key: string) => (dict[code]?.[key] ?? dict.en[key] ?? key)
}

export default function JobsPage() {
  const t = useI18n()
  const [q, setQ] = useState('')
  const [canton, setCanton] = useState<string>('')
  const [results, setResults] = useState<JobItem[]>([])
  const [top, setTop] = useState<{ keyword: string, canton?: string, count: number }[]>([])
  const [loading, setLoading] = useState(false)
  const [favorites, setFavorites] = useState<Record<string, JobItem>>({})
  const [notify, setNotify] = useState(false)
  const intervalRef = useRef<any>(null)

  // Load local favorites
  useEffect(() => {
    if (typeof window === 'undefined') return
    try {
      const raw = localStorage.getItem('job_favorites') || '{}'
      setFavorites(JSON.parse(raw))
    } catch {}
  }, [])

  function saveFavorites(next: Record<string, JobItem>) {
    setFavorites(next)
    if (typeof window !== 'undefined') localStorage.setItem('job_favorites', JSON.stringify(next))
  }

  async function searchJobs(log = true) {
    if (!q.trim()) return
    setLoading(true)
    try {
      const url = `/api/jobs/search?q=${encodeURIComponent(q)}&canton=${encodeURIComponent(canton)}`
      const res = await fetch(url, { cache: 'no-store' })
      const data = await res.json()
      setResults(Array.isArray(data.items) ? data.items : [])
      if (log) fetch(`/api/jobs/analytics/top`, { cache: 'no-store' }) // warm analytics endpoint
      // refresh top analytics list
      try {
        const topRes = await fetch('/api/jobs/analytics/top', { cache: 'no-store' })
        const topData = await topRes.json()
        if (Array.isArray(topData)) setTop(topData)
      } catch {}
      // fire analytics event (best-effort, via local API to avoid CORS)
      fetch(`/api/jobs/analytics/events?keyword=${encodeURIComponent(q)}&canton=${encodeURIComponent(canton)}`, { method: 'POST' }).catch(() => {})
      // track last seen ids for notifications
      if (typeof window !== 'undefined') {
        const key = `job_seen_${q}_${canton}`
        const ids = (data.items || []).map((it: JobItem) => it.id)
        localStorage.setItem(key, JSON.stringify(ids))
      }
    } finally {
      setLoading(false)
    }
  }

  function toggleFavorite(job: JobItem) {
    const next = { ...favorites }
    if (next[job.id]) {
      delete next[job.id]
      // also try to delete on backend if exists
      // (we do not track backend id here for simplicity)
    } else {
      next[job.id] = job
      // best-effort sync to backend if logged-in
      fetch('/api/jobs/favorites', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          job_id: job.id,
          source: job.source,
          title: job.title,
          company: job.company,
          location: job.location,
          canton: job.canton,
          url: job.url
        })
      }).catch(() => {})
    }
    saveFavorites(next)
  }

  async function draftApplication(job: JobItem) {
    const res = await fetch('/api/ai/job-apply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jobTitle: job.title,
        company: job.company,
        description: job.snippet,
        language: (localStorage.getItem('lang') || 'en')
      })
    })
    const data = await res.json()
    if (data?.text) {
      await navigator.clipboard.writeText(data.text)
      alert(t('copied'))
    }
  }

  // Notifications about new jobs for current filters
  useEffect(() => {
    if (!notify) {
      if (intervalRef.current) clearInterval(intervalRef.current)
      return
    }
    if (typeof window === 'undefined') return
    Notification.requestPermission().then(() => {})
    intervalRef.current = setInterval(async () => {
      if (!q.trim()) return
      const res = await fetch(`/api/jobs/search?q=${encodeURIComponent(q)}&canton=${encodeURIComponent(canton)}`, { cache: 'no-store' })
      const data = await res.json()
      const newIds: string[] = (data.items || []).map((it: JobItem) => it.id)
      const key = `job_seen_${q}_${canton}`
      const prev = JSON.parse(localStorage.getItem(key) || '[]')
      const diff = newIds.filter(id => !prev.includes(id))
      if (diff.length > 0 && Notification.permission === 'granted') {
        new Notification('New jobs available', { body: `${diff.length} new results for "${q}"` })
        localStorage.setItem(key, JSON.stringify(newIds))
      }
    }, 60000)
    return () => { if (intervalRef.current) clearInterval(intervalRef.current) }
  }, [notify, q, canton])

  return (
    <div className="p-6 space-y-4">
      <Card>
        <div className="flex items-center justify-between pb-3">
          <div className="text-xl font-semibold">{t('title')}</div>
        </div>
        <div className="flex flex-col md:flex-row gap-3">
          <input
            placeholder={t('searchPlaceholder')}
            value={q}
            onChange={e => setQ(e.target.value)}
            className="glass px-3 py-2 rounded-md flex-1"
          />
          <select value={canton} onChange={e => setCanton(e.target.value)} className="glass px-3 py-2 rounded-md w-full md:w-48">
            <option value="">{t('canton')}</option>
            {CANTONS.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
          <button onClick={() => searchJobs()} className="glass px-4 py-2 rounded-md">{loading ? '...' : t('search')}</button>
        </div>
        <div className="mt-3 flex items-center gap-2">
          <input id="notify" type="checkbox" checked={notify} onChange={e => setNotify(e.target.checked)} />
          <label htmlFor="notify" className="text-sm opacity-80">{t('notify')}</label>
        </div>
      </Card>

      <Card>
        <div className="text-sm opacity-70 mb-2">{t('results')}</div>
        {results.length === 0 && (
          <div className="text-sm opacity-60">{t('empty')}</div>
        )}
        <div className="grid grid-cols-1 gap-3">
          {results.map(job => {
            const fav = !!favorites[job.id]
            return (
              <div key={job.id} className="glass p-3 rounded-lg flex flex-col md:flex-row md:items-center gap-3">
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <div className="font-medium">{job.title}</div>
                    <span className="text-xs px-2 py-0.5 rounded-full bg-white/10">{job.source.toUpperCase()}</span>
                  </div>
                  <div className="text-sm opacity-80">{job.company ?? ''} {job.location ? `• ${job.location}` : ''} {job.canton ? `• ${job.canton}` : ''}</div>
                  {job.snippet && <div className="text-sm opacity-70 line-clamp-2 mt-1">{job.snippet}</div>}
                </div>
                <div className="flex items-center gap-2">
                  <a href={job.url} target="_blank" rel="noreferrer" className="glass px-3 py-1.5 rounded-md">Open</a>
                  <button onClick={() => draftApplication(job)} className="glass px-3 py-1.5 rounded-md">{t('apply')}</button>
                  <button onClick={() => toggleFavorite(job)} className="glass px-3 py-1.5 rounded-md">{fav ? t('unfavorite') : t('favorite')}</button>
                </div>
              </div>
            )
          })}
        </div>
      </Card>
      
      {top.length > 0 && (
        <Card>
          <div className="text-sm opacity-70 mb-2">Top searches</div>
          <div className="flex flex-wrap gap-2">
            {top.map((e, idx) => (
              <span key={idx} className="glass px-2 py-1 rounded-md text-sm">
                {e.keyword} {e.canton ? `(${e.canton})` : ''} — {e.count}
              </span>
            ))}
          </div>
        </Card>
      )}
    </div>
  )
}



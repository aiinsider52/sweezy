export type User = {
  id: string
  email: string
  is_superuser: boolean
  created_at: string
}

export type News = {
  id: string
  title: string
  summary: string
  content?: string
  url: string
  source: string
  language: string
  status?: 'draft' | 'published' | 'archived'
  import_source?: 'manual' | 'rss' | 'brave' | string
  import_reference_id?: string | null
  published_at: string
  image_url?: string | null
}

export type BraveNewsQuery = {
  id: string
  query: string
  language: string
  country?: string | null
  status: 'draft' | 'published'
  enabled: boolean
  max_results: number
  freshness_days: number
  last_imported_at?: string | null
  created_at?: string | null
  updated_at?: string | null
}



import { serverFetch } from '@/lib/server'

export async function GET(request: Request) {
  const query = new URL(request.url).search
  const response = await serverFetch(`/admin/incidents${query}`)
  return new Response(await response.text(), {
    status: response.status,
    headers: { 'Content-Type': 'application/json' },
  })
}

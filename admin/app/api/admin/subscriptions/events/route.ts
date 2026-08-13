import { serverFetch } from "@/lib/server"

export async function GET() {
  const res = await serverFetch("/admin/subscriptions/events")
  const text = await res.text()
  return new Response(text, { status: res.status, headers: { "Content-Type": res.headers.get("Content-Type") || "application/json", "Cache-Control": "private, no-store" } })
}


import { NextRequest } from "next/server"
import { serverFetch } from "@/lib/server"

export async function GET(req: NextRequest) {
  const months = req.nextUrl.searchParams.get("months") || "6"
  const res = await serverFetch(`/admin/subscriptions/analytics?months=${encodeURIComponent(months)}`)
  const text = await res.text()
  return new Response(text, { status: res.status, headers: { "Content-Type": res.headers.get("Content-Type") || "application/json", "Cache-Control": "private, no-store" } })
}


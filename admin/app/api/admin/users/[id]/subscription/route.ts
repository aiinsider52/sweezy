import { NextRequest } from "next/server"
import { serverFetch } from "@/lib/server"

export async function POST(req: NextRequest, props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  const body = await req.text()
  const res = await serverFetch(`/admin/users/${encodeURIComponent(params.id)}/subscription`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body,
  })
  const text = await res.text()
  return new Response(text, { status: res.status, headers: { "Content-Type": res.headers.get("Content-Type") || "application/json", "Cache-Control": "private, no-store" } })
}


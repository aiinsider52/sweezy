import { NextRequest, NextResponse } from "next/server"
import { serverFetch } from "@/lib/server"

export async function GET(req: NextRequest) {
  const days = req.nextUrl.searchParams.get("days") || "30"
  try {
    const r = await serverFetch(`/admin/paywall/funnel?days=${encodeURIComponent(days)}`)
    const data = await r.json().catch(() => ({}))
    return NextResponse.json(data, { status: r.status })
  } catch {
    return NextResponse.json({ error: "failed" }, { status: 500 })
  }
}



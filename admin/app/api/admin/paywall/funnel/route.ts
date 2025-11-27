import { NextRequest, NextResponse } from "next/server"

export async function GET(req: NextRequest) {
  const base = process.env.NEXT_PUBLIC_API_BASE || process.env.API_BASE || "https://sweezy.onrender.com"
  const url = new URL(`${base}/api/v1/admin/paywall/funnel`)
  const days = req.nextUrl.searchParams.get("days") || "30"
  url.searchParams.set("days", days)
  try {
    const r = await fetch(url.toString(), { cache: "no-store", headers: { "x-admin": "1" } })
    const data = await r.json().catch(() => ({}))
    return NextResponse.json(data, { status: r.status })
  } catch {
    return NextResponse.json({ error: "failed" }, { status: 500 })
  }
}



"use server"
import { NextRequest, NextResponse } from "next/server"
import { cookies } from "next/headers"

export async function GET(req: NextRequest) {
  const token = cookies().get("access_token")?.value || ""
  const base = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-9xyk.onrender.com/api/v1"
  const months = req.nextUrl.searchParams.get("months") || "6"
  const res = await fetch(`${base}/admin/subscriptions/analytics?months=${encodeURIComponent(months)}`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: "no-store",
  })
  const text = await res.text()
  return new NextResponse(text, { status: res.status, headers: { "Content-Type": res.headers.get("Content-Type") || "application/json" } })
}



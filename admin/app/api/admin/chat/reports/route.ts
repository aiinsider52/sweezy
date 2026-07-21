"use server"
import { NextRequest, NextResponse } from "next/server"
import { cookies } from "next/headers"

export async function GET(req: NextRequest) {
  const token = (await cookies()).get("access_token")?.value || ""
  const base = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-9xyk.onrender.com/api/v1"
  const status = req.nextUrl.searchParams.get("status") || "open"
  const res = await fetch(`${base}/admin/chat/reports?status=${encodeURIComponent(status)}`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: "no-store",
  })
  return new NextResponse(await res.text(), {
    status: res.status,
    headers: { "Content-Type": res.headers.get("Content-Type") || "application/json" },
  })
}

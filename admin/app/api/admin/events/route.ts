"use server"
import { NextRequest, NextResponse } from "next/server"
import { cookies } from "next/headers"

export async function GET(req: NextRequest) {
  const token = (await cookies()).get("access_token")?.value || ""
  const base = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-9xyk.onrender.com/api/v1"
  const qs = req.nextUrl.searchParams.toString()
  const suffix = qs ? `?${qs}` : ""
  const res = await fetch(`${base}/admin/events${suffix}`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: "no-store",
  })
  const text = await res.text()
  return new NextResponse(text, { status: res.status, headers: { "Content-Type": res.headers.get("Content-Type") || "application/json" } })
}

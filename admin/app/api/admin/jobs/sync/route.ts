"use server"
import { NextRequest, NextResponse } from "next/server"
import { cookies } from "next/headers"

export async function POST(request: NextRequest) {
  const token = (await cookies()).get("access_token")?.value || ""
  const base = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-9xyk.onrender.com/api/v1"
  const query = request.nextUrl.searchParams.toString()
  const response = await fetch(`${base}/admin/jobs/sync${query ? `?${query}` : ""}`, { method: "POST", headers: { Authorization: `Bearer ${token}` }, cache: "no-store" })
  return new NextResponse(await response.text(), { status: response.status, headers: { "Content-Type": "application/json" } })
}

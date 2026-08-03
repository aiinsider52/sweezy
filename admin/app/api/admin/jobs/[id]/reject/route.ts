"use server"
import { NextRequest, NextResponse } from "next/server"
import { cookies } from "next/headers"

export async function POST(request: NextRequest, props: { params: Promise<{ id: string }> }) {
  const { id } = await props.params
  const reason = request.nextUrl.searchParams.get("reason") || "Rejected by moderation"
  const token = (await cookies()).get("access_token")?.value || ""
  const base = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-9xyk.onrender.com/api/v1"
  const response = await fetch(`${base}/admin/jobs/${encodeURIComponent(id)}/reject?reason=${encodeURIComponent(reason)}`, { method: "POST", headers: { Authorization: `Bearer ${token}` } })
  return new NextResponse(await response.text(), { status: response.status, headers: { "Content-Type": "application/json" } })
}

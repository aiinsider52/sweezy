"use server"
import { NextRequest, NextResponse } from "next/server"
import { cookies } from "next/headers"

export async function PATCH(request: NextRequest, props: { params: Promise<{ id: string }> }) {
  const { id } = await props.params
  const token = (await cookies()).get("access_token")?.value || ""
  const base = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-api.onrender.com/api/v1"
  const res = await fetch(`${base}/admin/business-reviews/${encodeURIComponent(id)}`, {
    method: "PATCH",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: await request.text(),
  })
  return new NextResponse(await res.text(), { status: res.status, headers: { "Content-Type": res.headers.get("Content-Type") || "application/json" } })
}

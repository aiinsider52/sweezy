"use server"
import { NextRequest, NextResponse } from "next/server"
import { cookies } from "next/headers"

const BASE = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-9xyk.onrender.com/api/v1"

export async function PATCH(req: NextRequest, props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  const token = (await cookies()).get("access_token")?.value || ""
  const body = await req.text()
  const res = await fetch(`${BASE}/admin/expert-questions/${params.id}/answer`, {
    method: "PATCH",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body,
  })
  const text = await res.text()
  return new NextResponse(text, {
    status: res.status,
    headers: { "Content-Type": res.headers.get("Content-Type") || "application/json" },
  })
}

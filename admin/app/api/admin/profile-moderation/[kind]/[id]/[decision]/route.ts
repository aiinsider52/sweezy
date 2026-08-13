"use server"
import { NextRequest, NextResponse } from "next/server"
import { cookies } from "next/headers"

export async function PATCH(req: NextRequest, props: { params: Promise<{ kind: string; id: string; decision: string }> }) {
  const { kind, id, decision } = await props.params
  if (!["social", "professional"].includes(kind) || !["approve", "reject"].includes(decision)) {
    return NextResponse.json({ detail: "Invalid moderation action" }, { status: 400 })
  }
  const token = (await cookies()).get("access_token")?.value || ""
  const base = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-9xyk.onrender.com/api/v1"
  const body = await req.text()
  const res = await fetch(`${base}/admin/profile-moderation/${kind}/${id}/${decision}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: body || "{}",
  })
  const text = await res.text()
  return new NextResponse(text, { status: res.status, headers: { "Content-Type": res.headers.get("Content-Type") || "application/json" } })
}

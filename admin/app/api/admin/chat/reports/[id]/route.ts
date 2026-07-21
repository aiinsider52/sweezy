"use server"
import { NextRequest, NextResponse } from "next/server"
import { cookies } from "next/headers"

export async function PATCH(req: NextRequest, props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  const token = (await cookies()).get("access_token")?.value || ""
  const base = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-9xyk.onrender.com/api/v1"
  const res = await fetch(`${base}/admin/chat/reports/${params.id}`, {
    method: "PATCH",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: await req.text(),
  })
  return new NextResponse(await res.text(), {
    status: res.status,
    headers: { "Content-Type": res.headers.get("Content-Type") || "application/json" },
  })
}

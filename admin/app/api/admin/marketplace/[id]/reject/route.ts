"use server"
import { NextRequest, NextResponse } from "next/server"
import { cookies } from "next/headers"

export async function PATCH(req: NextRequest, props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  const token = (await cookies()).get("access_token")?.value || ""
  const base = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-9xyk.onrender.com/api/v1"
  const body = await req.text()
  const res = await fetch(`${base}/admin/marketplace/${params.id}/reject`, {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body,
  })
  const text = await res.text()
  return new NextResponse(text, { status: res.status, headers: { "Content-Type": res.headers.get("Content-Type") || "application/json" } })
}

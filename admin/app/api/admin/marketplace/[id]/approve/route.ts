"use server"
import { NextRequest, NextResponse } from "next/server"
import { cookies } from "next/headers"

export async function PATCH(_req: NextRequest, { params }: { params: { id: string } }) {
  const token = cookies().get("access_token")?.value || ""
  const base = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-9xyk.onrender.com/api/v1"
  const res = await fetch(`${base}/admin/marketplace/${params.id}/approve`, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })
  const text = await res.text()
  return new NextResponse(text, { status: res.status, headers: { "Content-Type": res.headers.get("Content-Type") || "application/json" } })
}

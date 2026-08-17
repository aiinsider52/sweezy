"use server"

import { cookies } from "next/headers"
import { NextRequest, NextResponse } from "next/server"

export async function PATCH(request: NextRequest, props: { params: Promise<{ id: string }> }) {
  const { id } = await props.params
  const token = (await cookies()).get("access_token")?.value || ""
  const base = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-9xyk.onrender.com/api/v1"
  const response = await fetch(`${base}/admin/businesses/${encodeURIComponent(id)}/review`, {
    method: "PATCH",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: await request.text(),
  })
  return new NextResponse(await response.text(), {
    status: response.status,
    headers: { "Content-Type": response.headers.get("Content-Type") || "application/json" },
  })
}

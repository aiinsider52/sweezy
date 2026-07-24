"use server"
import { NextRequest, NextResponse } from "next/server"
import { cookies } from "next/headers";

const BASE = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-9xyk.onrender.com/api/v1"

async function token() {
  return (await cookies()).get("access_token")?.value || "";
}

export async function PATCH(req: NextRequest, props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  const body = await req.text()
  const res = await fetch(`${BASE}/admin/moments/${params.id}`, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${await token()}`,
      "Content-Type": "application/json",
    },
    body,
  })
  const text = await res.text()
  return new NextResponse(text, {
    status: res.status,
    headers: { "Content-Type": res.headers.get("Content-Type") || "application/json" },
  })
}

export async function DELETE(_req: NextRequest, props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  const res = await fetch(`${BASE}/admin/moments/${params.id}`, {
    method: "DELETE",
    headers: { Authorization: `Bearer ${await token()}` },
  })
  return new NextResponse(null, { status: res.status })
}

"use server"
import { NextRequest, NextResponse } from "next/server"
import { cookies } from "next/headers";

const BASE = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-9xyk.onrender.com/api/v1"

async function token() {
  return (await cookies()).get("access_token")?.value || "";
}

export async function GET(req: NextRequest) {
  const qs = req.nextUrl.searchParams.toString()
  const suffix = qs ? `?${qs}` : ""
  const res = await fetch(`${BASE}/admin/moments${suffix}`, {
    headers: { Authorization: `Bearer ${await token()}` },
    cache: "no-store",
  })
  const text = await res.text()
  return new NextResponse(text, {
    status: res.status,
    headers: { "Content-Type": res.headers.get("Content-Type") || "application/json" },
  })
}

export async function POST(req: NextRequest) {
  const body = await req.text()
  const res = await fetch(`${BASE}/admin/moments`, {
    method: "POST",
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

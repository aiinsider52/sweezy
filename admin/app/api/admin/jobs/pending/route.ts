"use server"
import { NextResponse } from "next/server"
import { cookies } from "next/headers"

export async function GET() {
  const token = (await cookies()).get("access_token")?.value || ""
  const base = process.env.NEXT_PUBLIC_API_URL || "https://sweezy-9xyk.onrender.com/api/v1"
  const response = await fetch(`${base}/admin/jobs/pending`, { headers: { Authorization: `Bearer ${token}` }, cache: "no-store" })
  return new NextResponse(await response.text(), { status: response.status, headers: { "Content-Type": "application/json" } })
}

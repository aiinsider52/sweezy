"use server"
import { NextRequest, NextResponse } from "next/server"
import { cookies } from "next/headers"

// Server-side so the admin CSP can stay strict and Nominatim gets an identifying User-Agent.
export async function GET(req: NextRequest) {
  const token = (await cookies()).get("access_token")?.value
  if (!token) return NextResponse.json({ detail: "Unauthorized" }, { status: 401 })
  const query = req.nextUrl.searchParams.get("q")?.trim()
  const country = (req.nextUrl.searchParams.get("country") || "ch").toLowerCase()
  if (!query || !["ch", "de", "at"].includes(country)) {
    return NextResponse.json({ detail: "Invalid query" }, { status: 400 })
  }
  const url = `https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=${country}&q=${encodeURIComponent(query)}`
  const res = await fetch(url, { headers: { "User-Agent": "SweezyAdmin/1.0 (place moderation)", "Accept-Language": "en" }, cache: "no-store" })
  if (!res.ok) return NextResponse.json({ detail: `Geocoder error (${res.status})` }, { status: 502 })
  const [hit] = await res.json()
  if (!hit) return NextResponse.json({ detail: "Address not found" }, { status: 404 })
  return NextResponse.json({ latitude: Number(hit.lat), longitude: Number(hit.lon), label: hit.display_name })
}

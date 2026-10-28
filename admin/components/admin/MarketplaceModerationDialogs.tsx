"use client"

import { FormEvent, useEffect, useState } from "react"
import { Dialog } from "@/components/ui/dialog"

export type ApprovePayload = {
  is_verified: boolean
  is_featured: boolean
  partner_label: string | null
  moderation_notes: string | null
  is_expert: boolean
  expert_specialty: string | null
  expert_languages: string[] | null
  response_time_hours: number | null
  expert_bio: string | null
}

const SPECIALTIES = ["tax", "legal", "insurance", "relocation", "career", "family"]

const fieldClass = "w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm outline-none focus:border-emerald-400/60"

// One form instead of a chain of window.confirm/prompt calls, which embedded
// browsers suppress (the Approve button then silently did nothing).
export function ApproveListingDialog({
  title,
  busy,
  onCancel,
  onApprove,
}: {
  title: string | null
  busy: boolean
  onCancel: () => void
  onApprove: (payload: ApprovePayload) => void
}) {
  const [verified, setVerified] = useState(false)
  const [featured, setFeatured] = useState(false)
  const [partnerLabel, setPartnerLabel] = useState("")
  const [expert, setExpert] = useState(false)
  const [specialty, setSpecialty] = useState("tax")
  const [languages, setLanguages] = useState("de,en")
  const [responseHours, setResponseHours] = useState("24")
  const [bio, setBio] = useState("")
  const [notes, setNotes] = useState("")

  useEffect(() => {
    if (title === null) return
    setVerified(false)
    setFeatured(false)
    setPartnerLabel("")
    setExpert(false)
    setSpecialty("tax")
    setLanguages("de,en")
    setResponseHours("24")
    setBio("")
    setNotes("")
  }, [title])

  function submit(event: FormEvent) {
    event.preventDefault()
    const hours = Number(responseHours)
    onApprove({
      is_verified: verified,
      is_featured: featured,
      partner_label: featured ? partnerLabel.trim() || null : null,
      moderation_notes: notes.trim() || null,
      is_expert: expert,
      expert_specialty: expert ? specialty : null,
      expert_languages: expert ? languages.split(",").map(s => s.trim().toLowerCase()).filter(Boolean) : null,
      response_time_hours: expert && Number.isFinite(hours) && hours > 0 ? hours : null,
      expert_bio: expert ? bio.trim() || null : null,
    })
  }

  return (
    <Dialog open={title !== null} onClose={onCancel} size="md">
      <form onSubmit={submit} className="space-y-5">
        <div>
          <div className="text-xs uppercase tracking-wide opacity-60">Approve listing</div>
          <h2 className="mt-1 text-lg font-semibold">{title}</h2>
        </div>

        <div className="space-y-3">
          <Toggle checked={verified} onChange={setVerified} label="Verified" hint="Shows the verified badge." />
          <Toggle checked={featured} onChange={setFeatured} label="Featured partner" hint="Pinned higher with a partner label." />
          {featured && (
            <input className={fieldClass} placeholder="Partner label (optional)" value={partnerLabel} onChange={e => setPartnerLabel(e.target.value)} />
          )}
          <Toggle checked={expert} onChange={setExpert} label="Expert profile" hint="Visible in /experts." />
          {expert && (
            <div className="grid gap-2 rounded-lg border border-white/10 p-3">
              <select className={fieldClass} value={specialty} onChange={e => setSpecialty(e.target.value)}>
                {SPECIALTIES.map(s => <option key={s} value={s}>{s}</option>)}
              </select>
              <input className={fieldClass} placeholder="Languages, e.g. de,en,uk" value={languages} onChange={e => setLanguages(e.target.value)} />
              <input className={fieldClass} type="number" min={1} placeholder="Response time, hours" value={responseHours} onChange={e => setResponseHours(e.target.value)} />
              <textarea className={fieldClass} rows={2} placeholder="Short bio (optional)" value={bio} onChange={e => setBio(e.target.value)} />
            </div>
          )}
        </div>

        <textarea className={fieldClass} rows={2} placeholder="Moderation notes (optional)" value={notes} onChange={e => setNotes(e.target.value)} />

        <div className="flex justify-end gap-2">
          <button type="button" onClick={onCancel} className="rounded-lg bg-white/10 px-4 py-2 text-sm">Cancel</button>
          <button type="submit" disabled={busy} className="rounded-lg bg-emerald-500/80 px-4 py-2 text-sm font-semibold text-black disabled:opacity-50">
            {busy ? "Approving…" : "Approve"}
          </button>
        </div>
      </form>
    </Dialog>
  )
}

export function RejectListingDialog({
  title,
  busy,
  onCancel,
  onReject,
}: {
  title: string | null
  busy: boolean
  onCancel: () => void
  onReject: (reason: string) => void
}) {
  const [reason, setReason] = useState("")

  useEffect(() => {
    if (title !== null) setReason("")
  }, [title])

  function submit(event: FormEvent) {
    event.preventDefault()
    if (reason.trim()) onReject(reason.trim())
  }

  return (
    <Dialog open={title !== null} onClose={onCancel} size="md">
      <form onSubmit={submit} className="space-y-5">
        <div>
          <div className="text-xs uppercase tracking-wide opacity-60">Reject listing</div>
          <h2 className="mt-1 text-lg font-semibold">{title}</h2>
        </div>
        <textarea
          autoFocus
          className={fieldClass}
          rows={3}
          placeholder="Reason, shown to the author"
          value={reason}
          onChange={e => setReason(e.target.value)}
        />
        <div className="flex justify-end gap-2">
          <button type="button" onClick={onCancel} className="rounded-lg bg-white/10 px-4 py-2 text-sm">Cancel</button>
          <button type="submit" disabled={busy || !reason.trim()} className="rounded-lg bg-red-500/80 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50">
            {busy ? "Rejecting…" : "Reject"}
          </button>
        </div>
      </form>
    </Dialog>
  )
}

function Toggle({ checked, onChange, label, hint }: { checked: boolean; onChange: (value: boolean) => void; label: string; hint: string }) {
  return (
    <label className="flex cursor-pointer items-start gap-3 rounded-lg border border-white/10 px-3 py-2 hover:bg-white/5">
      <input type="checkbox" className="mt-1 h-4 w-4 accent-emerald-400" checked={checked} onChange={e => onChange(e.target.checked)} />
      <span>
        <span className="block text-sm font-medium">{label}</span>
        <span className="block text-xs opacity-60">{hint}</span>
      </span>
    </label>
  )
}

import ProfileModerationList from "@/components/admin/ProfileModerationList"

export default function ProfileModerationPage() {
  return <section className="space-y-6 pb-12">
    <header className="rounded-[28px] border border-lime-300/20 bg-[#101510] p-6 md:p-8">
      <p className="text-xs font-bold uppercase tracking-[.22em] text-lime-300">Trust & Safety</p>
      <h1 className="mt-2 text-3xl font-black tracking-tight md:text-5xl">Social Passports</h1>
      <p className="mt-3 max-w-2xl text-sm leading-6 text-white/55">New and edited profiles stay hidden until approval. Review identity, location, bio, interests and meeting preferences here.</p>
    </header>
    <ProfileModerationList initialKind="social" />
  </section>
}

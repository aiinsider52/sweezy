import PlaceSuggestionList from "@/components/admin/PlaceSuggestionList"

export default function PlaceSuggestionsPage() {
  return <section className="space-y-6 pb-12">
    <header className="rounded-[28px] border border-lime-300/20 bg-[#101510] p-6 md:p-8">
      <p className="text-xs font-bold uppercase tracking-[.22em] text-lime-300">Community map</p>
      <h1 className="mt-2 text-3xl font-black tracking-tight md:text-5xl">Place suggestions</h1>
      <p className="mt-3 max-w-2xl text-sm leading-6 text-white/55">Places proposed by users stay hidden until approved. Check that the place exists (website, phone, map), set the exact coordinates, then approve. Approved places appear on everyone’s map.</p>
    </header>
    <PlaceSuggestionList />
  </section>
}

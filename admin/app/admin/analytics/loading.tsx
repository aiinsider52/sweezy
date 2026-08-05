import Skeleton from '@/components/Skeleton'

export default function Loading() {
  return (
    <section className="space-y-6">
      <Skeleton className="h-16 w-full max-w-sm" />
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {Array.from({ length: 4 }, (_, index) => <Skeleton key={index} className="h-32" />)}
      </div>
      <div className="grid gap-6 xl:grid-cols-5">
        <Skeleton className="h-80 xl:col-span-3" />
        <Skeleton className="h-80 xl:col-span-2" />
      </div>
    </section>
  )
}

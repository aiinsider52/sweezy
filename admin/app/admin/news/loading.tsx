import Skeleton from '@/components/Skeleton'
import Card from '@/components/Card'

export default function NewsLoading() {
  return (
    <section className="space-y-8">
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-5 gap-6">
        <Skeleton className="h-32" />
        <Skeleton className="h-32" />
        <Skeleton className="h-32" />
        <Skeleton className="h-32" />
        <Skeleton className="h-32" />
      </div>
      <Card className="h-96">
        <Skeleton className="h-full w-full" />
      </Card>
    </section>
  )
}



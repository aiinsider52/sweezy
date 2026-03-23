import Card from '@/components/Card'
import EventsModerationList from '@/components/admin/EventsModerationList'

export default function EventsPage() {
  return (
    <section className="space-y-8">
      <Card title="Events moderation">
        <EventsModerationList />
      </Card>
    </section>
  )
}

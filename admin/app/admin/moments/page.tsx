import Card from '@/components/Card'
import MomentsManager from '@/components/admin/MomentsManager'

export default function MomentsPage() {
  return (
    <section className="space-y-8">
      <Card title="Swiss moments calendar">
        <MomentsManager />
      </Card>
    </section>
  )
}

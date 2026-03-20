import Card from '@/components/Card'
import MarketplaceModerationList from '@/components/admin/MarketplaceModerationList'

export default function MarketplacePage() {
  return (
    <section className="space-y-8">
      <Card title="Marketplace moderation">
        <MarketplaceModerationList />
      </Card>
    </section>
  )
}

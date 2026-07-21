import Card from '@/components/Card'
import ExpertQuestionsList from '@/components/admin/ExpertQuestionsList'

export default function ExpertQuestionsPage() {
  return (
    <section className="space-y-8">
      <Card title="Expert Q&A moderation">
        <ExpertQuestionsList />
      </Card>
    </section>
  )
}

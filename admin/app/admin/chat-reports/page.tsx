import Card from "@/components/Card"
import ChatReportsList from "@/components/admin/ChatReportsList"

export default function ChatReportsPage() {
  return (
    <section className="space-y-8">
      <Card title="Chat safety reports">
        <p className="mb-5 text-sm opacity-60">Only reported message plus bounded context is exposed. Private conversations are not browsable.</p>
        <ChatReportsList />
      </Card>
    </section>
  )
}

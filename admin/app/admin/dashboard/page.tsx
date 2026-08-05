import Link from 'next/link'
import { ArrowRight } from 'lucide-react'
import AnalyticsDashboard from '@/components/analytics/AnalyticsDashboard'

export default function DashboardPage() {
  return (
    <div className="space-y-6">
      <AnalyticsDashboard compact />
      <div className="flex justify-end">
        <Link href="/admin/analytics" className="inline-flex items-center gap-2 text-sm font-medium text-cyan-300 hover:text-cyan-200">
          Open detailed analytics <ArrowRight size={16} />
        </Link>
      </div>
    </div>
  )
}


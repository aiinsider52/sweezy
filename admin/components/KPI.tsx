"use client"
import Card from './Card'

type IconKind = 'users' | 'guides' | 'templates' | 'server'

export default function KPI({ title, value, className, icon: _icon, delta: _delta }: { title: string; value: string | number; className?: string; icon?: IconKind; delta?: number }) {
  return (
    <div className={`relative ${className ?? ''}`}>
      <div className="absolute -inset-0.5 rounded-2xl bg-gradient-to-br from-cyan-400/25 via-fuchsia-400/20 to-amber-400/20 blur-md animate-pulse" aria-hidden="true" />
      <Card title={title} className="relative">
        <div className="flex items-center justify-between">
          <div className="text-4xl font-semibold tracking-tight">{value}</div>
          <div className="opacity-70" aria-hidden="true" />
        </div>
      </Card>
    </div>
  )
}



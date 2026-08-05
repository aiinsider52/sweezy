'use client'

import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'

export type ChartPoint = { label: string; value: number; secondary?: number }

const tooltipStyle = {
  background: '#11161d',
  border: '1px solid rgba(255,255,255,.12)',
  borderRadius: 12,
}

export function TrendChart({ data }: { data: ChartPoint[] }) {
  return (
    <div className="h-72 w-full" role="img" aria-label="Analytics trend chart">
      <ResponsiveContainer>
        <AreaChart data={data} margin={{ left: -18, right: 8, top: 10 }}>
          <defs>
            <linearGradient id="analyticsTrend" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#22d3ee" stopOpacity={0.45} />
              <stop offset="100%" stopColor="#22d3ee" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid stroke="rgba(255,255,255,.07)" vertical={false} />
          <XAxis dataKey="label" stroke="#8b98a8" tickLine={false} axisLine={false} minTickGap={24} />
          <YAxis stroke="#8b98a8" tickLine={false} axisLine={false} />
          <Tooltip contentStyle={tooltipStyle} />
          <Area type="monotone" dataKey="value" stroke="#22d3ee" strokeWidth={2.5} fill="url(#analyticsTrend)" />
          <Area type="monotone" dataKey="secondary" stroke="#a78bfa" strokeWidth={2} fill="transparent" />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  )
}

export function RankingChart({ data }: { data: ChartPoint[] }) {
  return (
    <div className="h-72 w-full" role="img" aria-label="Top content chart">
      <ResponsiveContainer>
        <BarChart data={data} layout="vertical" margin={{ left: 8, right: 16 }}>
          <CartesianGrid stroke="rgba(255,255,255,.07)" horizontal={false} />
          <XAxis type="number" stroke="#8b98a8" tickLine={false} axisLine={false} />
          <YAxis type="category" dataKey="label" width={110} stroke="#b7c0cc" tickLine={false} axisLine={false} />
          <Tooltip contentStyle={tooltipStyle} cursor={{ fill: 'rgba(255,255,255,.04)' }} />
          <Bar dataKey="value" fill="#a78bfa" radius={[0, 7, 7, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}

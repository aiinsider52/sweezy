"use client"
import { ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip } from 'recharts'

type Point = { name: string; value: number }

export default function Chart({ data }: { data: Point[] }) {
  return (
    <div className="h-64">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data}>
          <XAxis dataKey="name" stroke="#999" />
          <YAxis stroke="#999" />
          <Tooltip />
          <Bar dataKey="value" fill="#60a5fa" radius={[8,8,0,0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}



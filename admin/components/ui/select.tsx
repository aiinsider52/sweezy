"use client"
import { useEffect, useRef, useState } from 'react'
import { cn } from '@/lib/utils'

type Option = { value: string; label?: string }

type Props = {
  value: string
  onChange: (next: string) => void
  options: Option[]
  className?: string
  placeholder?: string
}

export default function UISelect({ value, onChange, options, className, placeholder }: Props) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)
  const selected = options.find(o => o.value === value)

  useEffect(() => {
    const onDoc = (e: MouseEvent) => {
      if (!ref.current) return
      if (!ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', onDoc)
    return () => document.removeEventListener('mousedown', onDoc)
  }, [])

  return (
    <div ref={ref} className={cn('relative', className)}>
      <button
        type="button"
        onClick={() => setOpen(v => !v)}
        className="glass w-full px-3 py-2 rounded-lg text-left inline-flex items-center justify-between"
      >
        <span className={cn(!selected && 'opacity-60')}>
          {selected?.label ?? selected?.value ?? placeholder ?? 'Select…'}
        </span>
        <span className="ml-2 opacity-70">▾</span>
      </button>
      {open && (
        <div className="absolute z-50 mt-1 w-full rounded-lg overflow-hidden border border-white/10 bg-bg/80 backdrop-blur-md shadow-lg">
          <ul className="max-h-64 overflow-auto">
            {options.map(opt => (
              <li key={opt.value}>
                <button
                  type="button"
                  onClick={() => { onChange(opt.value); setOpen(false) }}
                  className={cn(
                    'w-full text-left px-3 py-2 hover:bg-white/10 transition',
                    value === opt.value && 'bg-white/10'
                  )}
                >
                  {opt.label ?? opt.value}
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}



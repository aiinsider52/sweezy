"use client"
import { ReactNode, useEffect } from 'react'
import { createPortal } from 'react-dom'
import UIButton from './button'

type Size = 'md' | 'lg' | 'xl'

export function Dialog({ open, onClose, children, size = 'lg', contentClassName }: { open: boolean; onClose: () => void; children: ReactNode; size?: Size; contentClassName?: string }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [onClose])
  if (!open) return null
  const sizes: Record<Size, string> = { md: 'max-w-md', lg: 'max-w-2xl', xl: 'max-w-4xl' }
  return createPortal(
    <div className="fixed inset-0 z-50 flex items-center justify-center px-4">
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />
      <div className={`relative glass w-full ${sizes[size]} max-h-[85vh] overflow-auto p-0 ${contentClassName ?? ''}`}>
        <button onClick={onClose} className="absolute top-2 right-2 glass px-2 py-1 rounded-md text-sm">Close</button>
        <div className="p-6 md:p-8">
          {children}
        </div>
      </div>
    </div>,
    document.body
  )
}



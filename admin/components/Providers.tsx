"use client"
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'
import { Toaster } from 'react-hot-toast'

export function ReactQueryProvider({ children }: { children: React.ReactNode }) {
  const [client] = useState(() => new QueryClient())
  return (
    <QueryClientProvider client={client}>
      {children}
      <Toaster position="top-right" />
    </QueryClientProvider>
  )
}



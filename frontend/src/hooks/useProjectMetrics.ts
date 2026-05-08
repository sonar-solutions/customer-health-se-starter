import { useState } from 'react'
import { metricsApi } from '../services/api'
import type { ProjectMetrics } from '../types'

export function useProjectMetrics(accountId: number) {
  const [metrics, setMetrics] = useState<ProjectMetrics | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const fetch = async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await metricsApi.get(accountId)
      setMetrics(data)
    } catch (e) {
      setError(e instanceof Error ? e : new Error(String(e)))
    } finally {
      setLoading(false)
    }
  }

  return { metrics, loading, error, fetch }
}

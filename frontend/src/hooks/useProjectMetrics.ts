import { useState, useEffect } from 'react'
import { metricsApi } from '../services/api'
import type { ProjectMetrics } from '../types'

export function useProjectMetrics(accountId: number) {
  const [metrics, setMetrics] = useState<ProjectMetrics | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    metricsApi
      .get(accountId)
      .then(setMetrics)
      .catch((err: Error) => setError(err.message))
      .finally(() => setLoading(false))
  }, [accountId])

  return { metrics, loading, error }
}

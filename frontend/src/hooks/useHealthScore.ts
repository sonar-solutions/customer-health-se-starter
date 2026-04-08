import { useState } from 'react'
import { scoresApi } from '../services/api'
import type { ScoreRefreshResult } from '../types'

export function useHealthScore(accountId: number) {
  const [result, setResult] = useState<ScoreRefreshResult | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const refresh = async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await scoresApi.refresh(accountId)
      setResult(data)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error')
    } finally {
      setLoading(false)
    }
  }

  return { result, loading, error, refresh }
}

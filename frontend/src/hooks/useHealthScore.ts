import { useState } from 'react'
import { scoresApi } from '../services/api'
import type { ScoreRefreshResult } from '../types'

export function useHealthScore(accountId: number) {
  const [result, setResult] = useState<ScoreRefreshResult | null>(null)
  const [loading, setLoading] = useState(false)

  const refresh = async () => {
    setLoading(true)
    const data = await scoresApi.refresh(accountId)
    setResult(data)
    setLoading(false)
  }

  return { result, loading, refresh }
}


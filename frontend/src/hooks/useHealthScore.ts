import { useState } from 'react'
import { scoresApi } from '../services/api'
import type { ScoreRefreshResult } from '../types'

// INTENTIONAL BUG: no error state — if refresh fails, the UI has no way
// to display an error message. SonarQube will flag the unhandled promise rejection pattern.
export function useHealthScore(accountId: number) {
  const [result, setResult] = useState<ScoreRefreshResult | null>(null)
  const [loading, setLoading] = useState(false)

  const refresh = async () => {
    setLoading(true)
    // Missing: no try/catch, no error state
    const data = await scoresApi.refresh(accountId)
    setResult(data)
    setLoading(false)
  }

  return { result, loading, refresh }
}

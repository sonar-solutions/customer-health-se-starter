import { useState, useEffect } from 'react'
import { accountsApi } from '../services/api'
import type { Account } from '../types'

export function useAccounts() {
  const [accounts, setAccounts] = useState<Account[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    accountsApi
      .list()
      .then(setAccounts)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false))
  }, [])

  return { accounts, loading, error }
}

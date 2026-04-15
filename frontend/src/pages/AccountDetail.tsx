import { useState, useEffect } from 'react'
// page component
import { accountsApi } from '../services/api'
import { useHealthScore } from '../hooks/useHealthScore'
import { MetricBadge } from '../components/MetricBadge'
import type { Account } from '../types'

interface AccountDetailProps {
  accountId: number
}

export function AccountDetail({ accountId }: AccountDetailProps) {
  const [account, setAccount] = useState<Account | null>(null)
  const { result, loading: refreshing, refresh } = useHealthScore(accountId)

  useEffect(() => {
    accountsApi.get(accountId).then(setAccount)
  }, [accountId, result])

  if (!account) return <div className="p-8 text-gray-500">Loading...</div>

  return (
    <div className="p-8 max-w-2xl">
      <h1 className="text-2xl font-bold text-gray-900 mb-2">{account.name}</h1>
      <div className="flex items-center gap-3 mb-6">
        <MetricBadge status={account.quality_gate_status} />
        <span className="text-sm text-gray-500 uppercase">{account.tier}</span>
      </div>
      <dl className="grid grid-cols-2 gap-4 mb-6">
        <div>
          <dt className="text-sm text-gray-500">Health Score</dt>
          <dd className="text-3xl font-bold">
            {account.health_score !== null ? Math.round(account.health_score) : '—'}
          </dd>
        </div>
        <div>
          <dt className="text-sm text-gray-500">Last Scan</dt>
          <dd className="text-sm font-medium">
            {account.last_scan_at ? new Date(account.last_scan_at).toLocaleString() : 'Never'}
          </dd>
        </div>
        <div>
          <dt className="text-sm text-gray-500">Project Key</dt>
          <dd className="text-sm font-mono">{account.sonarqube_project_key ?? 'Not set'}</dd>
        </div>
        <div>
          <dt className="text-sm text-gray-500">Owner</dt>
          <dd className="text-sm">{account.owner ?? 'Unassigned'}</dd>
        </div>
      </dl>
      <button
        onClick={refresh}
        disabled={refreshing}
        className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50"
      >
        {refreshing ? 'Refreshing...' : 'Refresh Score'}
      </button>
    </div>
  )
}

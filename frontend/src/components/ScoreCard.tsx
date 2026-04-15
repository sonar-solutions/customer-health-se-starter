import type { Account } from '../types'
import type { ScoreRefreshResult } from '../services/api'
import { MetricBadge } from './MetricBadge'

type _RefreshResult = ScoreRefreshResult

interface ScoreCardProps {
  account: Account
  onRefresh?: (id: number) => void
}

function scoreColor(score: number | null): string {
  if (score === null) return 'text-gray-400'
  if (score >= 80) return 'text-green-600'
  if (score >= 50) return 'text-yellow-600'
  return 'text-red-600'
}

export function ScoreCard({ account, onRefresh }: ScoreCardProps) {
  return (
    <div className="bg-white rounded-lg shadow p-4 flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <h3 className="font-semibold text-gray-900 truncate">{account.name}</h3>
        <span className="text-xs text-gray-500 uppercase">{account.tier}</span>
      </div>
      <div className="flex items-center gap-2">
        <span className={`text-3xl font-bold ${scoreColor(account.health_score)}`}>
          {account.health_score !== null ? Math.round(account.health_score) : '—'}
        </span>
        <MetricBadge status={account.quality_gate_status} />
      </div>
      {account.last_scan_at && (
        <p className="text-xs text-gray-500">
          Last scan: {new Date(account.last_scan_at).toLocaleDateString()}
        </p>
      )}
      {onRefresh && (
        <button
          onClick={() => onRefresh(account.id)}
          className="mt-1 text-xs text-blue-600 hover:text-blue-800 text-left"
        >
          Refresh score
        </button>
      )}
    </div>
  )
}

import type { Account } from '../types'
import { ScoreCard } from './ScoreCard'

interface AccountListProps {
  accounts: Account[]
  onRefresh?: (id: number) => void
}

export function AccountList({ accounts, onRefresh }: AccountListProps) {
  if (accounts.length === 0) {
    return <p className="text-gray-500 text-sm">No accounts found.</p>
  }

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      {accounts.map((account) => (
        <ScoreCard key={account.id} account={account} onRefresh={onRefresh} />
      ))}
    </div>
  )
}

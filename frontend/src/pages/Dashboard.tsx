import { useAccounts } from '../hooks/useAccounts'
import { AccountList } from '../components/AccountList'

export function Dashboard() {
  const { accounts, loading, error } = useAccounts()

  if (loading) return <div className="p-8 text-gray-500">Loading accounts...</div>
  if (error) return <div className="p-8 text-red-600">Error: {error}</div>

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Customer Health Dashboard</h1>
      <AccountList accounts={accounts} />
    </div>
  )
}

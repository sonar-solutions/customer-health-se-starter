import { useState } from 'react'
import { Dashboard } from './pages/Dashboard'
import { AccountDetail } from './pages/AccountDetail'

export default function App() {
  const [selectedAccountId, setSelectedAccountId] = useState<number | null>(null)

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white shadow-sm px-8 py-4 flex items-center gap-4">
        <h1 className="font-bold text-blue-700">Customer Health</h1>
        {selectedAccountId && (
          <button
            onClick={() => setSelectedAccountId(null)}
            className="text-sm text-gray-600 hover:text-gray-900"
          >
            ← Back to Dashboard
          </button>
        )}
      </nav>
      {selectedAccountId ? (
        <AccountDetail accountId={selectedAccountId} />
      ) : (
        <Dashboard />
      )}
    </div>
  )
}

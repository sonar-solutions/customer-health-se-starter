import { render, screen, waitFor } from '@testing-library/react'
import { vi } from 'vitest'
import { Dashboard } from '../../src/pages/Dashboard'
import * as api from '../../src/services/api'
import type { Account } from '../../src/types'

const mockAccounts: Account[] = [
  {
    id: 1, name: 'Acme Corp', tier: 'enterprise',
    health_score: 90, quality_gate_status: 'OK',
    sonarqube_project_key: 'acme', sonarqube_url: null,
    owner: null, last_scan_at: null, is_active: true,
    created_at: '2024-01-01T00:00:00Z', updated_at: '2024-01-01T00:00:00Z',
  },
]

test('renders loading state initially', () => {
  vi.spyOn(api.accountsApi, 'list').mockResolvedValue(mockAccounts)
  render(<Dashboard />)
  expect(screen.getByText('Loading accounts...')).toBeInTheDocument()
})

test('renders account list after load', async () => {
  vi.spyOn(api.accountsApi, 'list').mockResolvedValue(mockAccounts)
  render(<Dashboard />)
  await waitFor(() => expect(screen.getByText('Acme Corp')).toBeInTheDocument())
})

test('renders error state on failure', async () => {
  vi.spyOn(api.accountsApi, 'list').mockRejectedValue(new Error('Network error'))
  render(<Dashboard />)
  await waitFor(() => expect(screen.getByText(/Network error/)).toBeInTheDocument())
})

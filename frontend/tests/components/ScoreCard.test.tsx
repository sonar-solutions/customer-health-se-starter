import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ScoreCard } from '../../src/components/ScoreCard'
import type { Account } from '../../src/types'

const mockAccount: Account = {
  id: 1,
  name: 'Acme Corp',
  sonarqube_project_key: 'acme:main',
  sonarqube_url: null,
  tier: 'enterprise',
  owner: 'Jane SE',
  health_score: 87.5,
  last_scan_at: '2024-03-15T10:00:00Z',
  quality_gate_status: 'OK',
  is_active: true,
  created_at: '2024-01-01T00:00:00Z',
  updated_at: '2024-03-15T10:00:00Z',
}

test('renders account name and score', () => {
  render(<ScoreCard account={mockAccount} />)
  expect(screen.getByText('Acme Corp')).toBeInTheDocument()
  expect(screen.getByText('88')).toBeInTheDocument()
})

test('calls onRefresh when button clicked', async () => {
  const onRefresh = vi.fn()
  render(<ScoreCard account={mockAccount} onRefresh={onRefresh} />)
  await userEvent.click(screen.getByText('Refresh score'))
  expect(onRefresh).toHaveBeenCalledWith(1)
})

test('renders dash for null score', () => {
  render(<ScoreCard account={{ ...mockAccount, health_score: null }} />)
  expect(screen.getByText('—')).toBeInTheDocument()
})

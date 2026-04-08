import { render, screen } from '@testing-library/react'
import { MetricBadge } from '../../src/components/MetricBadge'

test('renders OK status', () => {
  render(<MetricBadge status="OK" />)
  expect(screen.getByText('Passing')).toBeInTheDocument()
})

test('renders ERROR status', () => {
  render(<MetricBadge status="ERROR" />)
  expect(screen.getByText('Failing')).toBeInTheDocument()
})

test('renders NONE for null status', () => {
  render(<MetricBadge status={null} />)
  expect(screen.getByText('Not configured')).toBeInTheDocument()
})

test('renders custom label when provided', () => {
  render(<MetricBadge status="OK" label="Quality Gate" />)
  expect(screen.getByText('Quality Gate')).toBeInTheDocument()
})

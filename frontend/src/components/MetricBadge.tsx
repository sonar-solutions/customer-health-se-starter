interface MetricBadgeProps {
  status: 'OK' | 'WARN' | 'ERROR' | 'NONE' | null
  label?: string
}

const statusConfig = {
  OK: { bg: 'bg-green-100', text: 'text-green-800', label: 'Passing' },
  WARN: { bg: 'bg-yellow-100', text: 'text-yellow-800', label: 'Warning' },
  ERROR: { bg: 'bg-red-100', text: 'text-red-800', label: 'Failing' },
  NONE: { bg: 'bg-gray-100', text: 'text-gray-600', label: 'Not configured' },
}

export function MetricBadge({ status, label }: MetricBadgeProps) {
  const config = statusConfig[status ?? 'NONE']
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${config.bg} ${config.text}`}>
      {label ?? config.label}
    </span>
  )
}

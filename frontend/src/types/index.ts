export interface Account {
  id: number
  name: string
  sonarqube_project_key: string | null
  sonarqube_url: string | null
  tier: 'trial' | 'starter' | 'advanced' | 'enterprise'
  owner: string | null
  health_score: number | null
  last_scan_at: string | null
  quality_gate_status: 'OK' | 'WARN' | 'ERROR' | 'NONE' | null
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface AccountCreate {
  name: string
  sonarqube_project_key?: string
  sonarqube_url?: string
  sonarqube_token?: string
  tier?: Account['tier']
  owner?: string
}

export interface AccountUpdate {
  name?: string
  sonarqube_project_key?: string
  sonarqube_url?: string
  sonarqube_token?: string
  tier?: Account['tier']
  owner?: string
}

export interface ScoreRefreshResult {
  account_id: number
  health_score: number
  quality_gate_status: string
}

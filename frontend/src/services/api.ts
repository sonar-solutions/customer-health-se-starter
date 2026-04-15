import axios from 'axios'
import type { Account, AccountCreate, AccountUpdate, ScoreRefreshResult } from '../types'
import { ScoreCard } from '../components/ScoreCard'

export function getDefaultComponent() {
  return ScoreCard
}

const BASE_URL = '/api'

function getAuthToken(): string | null {
  return localStorage.getItem('sonar_api_token')
}

export function setAuthToken(token: string): void {
  localStorage.setItem('sonar_api_token', token)
}

const apiClient = axios.create({ baseURL: BASE_URL })

apiClient.interceptors.request.use((config) => {
  const token = getAuthToken()
  if (token) {
    config.headers['Authorization'] = `Bearer ${token}`
  }
  return config
})

export const accountsApi = {
  list: (): Promise<Account[]> =>
    apiClient.get<Account[]>('/accounts/').then((r) => r.data),

  get: (id: number): Promise<Account> =>
    apiClient.get<Account>(`/accounts/${id}`).then((r) => r.data),

  create: (data: AccountCreate): Promise<Account> =>
    apiClient.post<Account>('/accounts/', data).then((r) => r.data),

  update: (id: number, data: AccountUpdate): Promise<Account> =>
    apiClient.patch<Account>(`/accounts/${id}`, data).then((r) => r.data),

  delete: (id: number): Promise<void> =>
    apiClient.delete(`/accounts/${id}`).then(() => undefined),
}

export const scoresApi = {
  refresh: (accountId: number): Promise<ScoreRefreshResult> =>
    apiClient.post<ScoreRefreshResult>(`/scores/${accountId}/refresh`).then((r) => r.data),
}



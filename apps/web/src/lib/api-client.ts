/** PRD §18 — API client for NestJS backend */

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';

interface FetchOptions extends RequestInit {
  token?: string;
}

class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

async function request<T>(
  endpoint: string,
  options: FetchOptions = {},
): Promise<T> {
  const { token, ...fetchOptions } = options;

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...(fetchOptions.headers as Record<string, string> || {}),
  };

  const response = await fetch(`${API_BASE_URL}${endpoint}`, {
    ...fetchOptions,
    headers,
  });

  if (!response.ok) {
    throw new ApiError(response.status, await response.text());
  }

  if (response.status === 204) return undefined as T;
  return response.json();
}

// ── Auth ────────────────────────────────────────────────────

export const authApi = {
  google: (data: {
    idToken: string;
    email: string;
    displayName: string;
    avatarUrl?: string;
    providerId: string;
    refreshToken?: string;
  }) => request<{ accessToken: string; refreshToken: string; user: any }>('/auth/google', {
    method: 'POST',
    body: JSON.stringify(data),
  }),

  apple: (data: {
    identityToken: string;
    email: string;
    displayName: string;
    providerId: string;
  }) => request<{ accessToken: string; refreshToken: string; user: any }>('/auth/apple', {
    method: 'POST',
    body: JSON.stringify(data),
  }),

  refresh: (refreshToken: string) =>
    request<{ accessToken: string; refreshToken: string }>('/auth/refresh', {
      method: 'POST',
      body: JSON.stringify({ refreshToken }),
    }),
};

// ── Transactions ────────────────────────────────────────────

export const transactionsApi = {
  list: (token: string, params?: {
    page?: number;
    limit?: number;
    type?: string;
    from?: string;
    to?: string;
    categoryId?: string;
  }) => {
    const searchParams = new URLSearchParams();
    if (params?.page) searchParams.set('page', String(params.page));
    if (params?.limit) searchParams.set('limit', String(params.limit));
    if (params?.type) searchParams.set('type', params.type);
    if (params?.from) searchParams.set('from', params.from);
    if (params?.to) searchParams.set('to', params.to);
    if (params?.categoryId) searchParams.set('categoryId', params.categoryId);
    const qs = searchParams.toString();
    return request<{ data: any[]; meta: any }>(`/transactions${qs ? `?${qs}` : ''}`, { token });
  },

  create: (token: string, data: any) =>
    request<any>('/transactions', { method: 'POST', body: JSON.stringify(data), token }),

  update: (token: string, id: string, data: any) =>
    request<any>(`/transactions/${id}`, { method: 'PATCH', body: JSON.stringify(data), token }),

  delete: (token: string, id: string) =>
    request<void>(`/transactions/${id}`, { method: 'DELETE', token }),
};

// ── Categories ──────────────────────────────────────────────

export const categoriesApi = {
  list: (token: string) =>
    request<any[]>('/categories', { token }),

  create: (token: string, data: { name: string; colourHex: string }) =>
    request<any>('/categories', { method: 'POST', body: JSON.stringify(data), token }),

  update: (token: string, id: string, data: any) =>
    request<any>(`/categories/${id}`, { method: 'PATCH', body: JSON.stringify(data), token }),

  delete: (token: string, id: string) =>
    request<void>(`/categories/${id}`, { method: 'DELETE', token }),
};

// ── Budgets ─────────────────────────────────────────────────

export const budgetsApi = {
  list: (token: string) =>
    request<any[]>('/budgets', { token }),

  create: (token: string, data: any) =>
    request<any>('/budgets', { method: 'POST', body: JSON.stringify(data), token }),

  update: (token: string, id: string, data: any) =>
    request<any>(`/budgets/${id}`, { method: 'PATCH', body: JSON.stringify(data), token }),

  delete: (token: string, id: string) =>
    request<void>(`/budgets/${id}`, { method: 'DELETE', token }),
};

// ── Exchange Rates ──────────────────────────────────────────

export const exchangeRatesApi = {
  latest: (token: string, from: string, to: string) =>
    request<{ rate: number; date: string }>(`/exchange-rates/latest?from=${from}&to=${to}`, { token }),

  historical: (token: string, date: string, from: string, to: string) =>
    request<{ rate: number; date: string }>(`/exchange-rates/${date}?from=${from}&to=${to}`, { token }),
};

// ── Sync ────────────────────────────────────────────────────

export const syncApi = {
  push: (token: string, records: any[], clientTimestamp: string) =>
    request<{ accepted: number; conflicts: any[] }>('/sync/push', {
      method: 'POST',
      body: JSON.stringify({ records, clientTimestamp }),
      token,
    }),

  pull: (token: string, lastSyncTimestamp: string) =>
    request<{ transactions: any[]; categories: any[]; budgets: any[]; serverTimestamp: string }>('/sync/pull', {
      method: 'POST',
      body: JSON.stringify({ lastSyncTimestamp }),
      token,
    }),
};

export interface AdminUser { id: number; nickname: string; role: string }
interface ApiResponse<T> { code: number; message: string; data: T }
interface LoginData { accessToken: string; expiresAt: string; user: AdminUser }

const TOKEN_KEY = 'creatorhub_admin_token'
const USER_KEY = 'creatorhub_admin_user'

export function getToken() { return localStorage.getItem(TOKEN_KEY) }
export function getAdminUser(): AdminUser | null { const value=localStorage.getItem(USER_KEY); return value?JSON.parse(value) as AdminUser:null }
export function logout() { localStorage.removeItem(TOKEN_KEY); localStorage.removeItem(USER_KEY) }

export async function adminLogin(identifier: string, password: string) {
  const response = await fetch('/api/v1/admin/login', { method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({identifier,password}) })
  const result = await response.json() as ApiResponse<LoginData>
  if (!response.ok) throw new Error(result.message || '登录失败')
  localStorage.setItem(TOKEN_KEY,result.data.accessToken)
  localStorage.setItem(USER_KEY,JSON.stringify(result.data.user))
  return result.data.user
}

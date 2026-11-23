import { type CookieOptions, createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

function requireEnv(key: string): string {
  const value = process.env[key]
  if (!value) {
    throw new Error(`Missing environment variable: ${key}`)
  }
  return value
}

export async function createClient() {
  const cookieStore = await cookies()
  const supabaseUrl = requireEnv('NEXT_PUBLIC_SUPABASE_URL')
  const supabaseKey = requireEnv('NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY')

  return createServerClient(supabaseUrl, supabaseKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll()
      },
      setAll(cookiesToSet: { name: string; value: string; options?: CookieOptions }[]) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options)
          }
        } catch {
          // The `setAll` method was called from a Server Component
        }
      },
    },
  })
}

/**
 * Ambil JWT claims (sub, role) dari session Supabase Auth.
 * Mengembalikan null jika user belum login.
 */
export async function getUserClaims() {
  const supabase = await createClient()
  const {
    data: { session },
  } = await supabase.auth.getSession()

  if (!session) {
    return null
  }

  return {
    sub: session.user.id,
    role: session.user.role ?? 'authenticated',
  }
}

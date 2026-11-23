import { PrismaClient } from '../../src/generated'
import { prisma } from './client'

export type UserContext = {
  sub: string
  role: string
}

/**
 * Runs a function within a Prisma transaction with transaction-scoped user context.
 *
 * Sets `SET LOCAL ROLE authenticated` and `set_config('request.jwt.claims', ...)`
 * inside the transaction. On commit/rollback, both are automatically cleared.
 * Without a context, the runtime role has no grants → fail-closed (42501).
 *
 * @param claims - Minimal JWT claims: { sub, role } (OD-5 approved).
 * @param fn - Function receiving the Prisma transaction handle `tx`.
 * @returns The return value of `fn`.
 */
export async function withUserContext<T>(
  claims: UserContext,
  fn: (tx: Omit<PrismaClient<PrismaClientOptions, never, DefaultArgs>, "$connect" | "$disconnect" | "$on" | "$use" | "$extends">) => Promise<T>,
): Promise<T> {
  return prisma.$transaction(async (tx) => {
    await tx.$executeRaw`SET LOCAL ROLE authenticated`
    await tx.$executeRaw`
      SELECT set_config('request.jwt.claims', ${JSON.stringify({
        sub: claims.sub,
        role: claims.role,
      })}, true)
    `
    return fn(tx)
  })
}
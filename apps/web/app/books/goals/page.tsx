import { withUserContext } from '../../../src/lib/db'
import { getUserClaims } from '../../../src/lib/supabase'

export default async function GoalsPage() {
  const session = await getUserClaims()

  if (!session) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center p-4">
        <section className="flex w-full max-w-2xl flex-col items-center justify-center p-6">
          <h1 className="text-4xl font-bold tracking-tight">BookRate</h1>
          <p className="mt-4 text-xl text-gray-600">Silakan login untuk melanjutkan.</p>
          <a
            href="/login"
            className="mt-8 inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            Login
          </a>
        </section>
      </main>
    )
  }

  const claims = session

  const goals = await withUserContext(claims, async (tx) => {
    return tx.reading_goals.findMany({
      orderBy: { year: 'desc' },
    })
  })

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-4">
      <section className="flex w-full max-w-2xl flex-col items-center justify-center p-6">
        <h1 className="text-4xl font-bold tracking-tight">BookRate</h1>
        <p className="mt-4 text-xl text-gray-600">Daftar Tujuan Membaca</p>
        <div className="mt-8 flex flex-col gap-2">
          {goals.map((goal) => (
            <div
              key={goal.id}
              className="flex items-center justify-between p-3 bg-gray-50 rounded border border-gray-200"
            >
              <div>
                <span className="font-medium">
                  {goal.period} {goal.year}
                </span>
                <p className="text-sm text-gray-500">Target: {goal.target_books} buku</p>
              </div>
              <span className="text-sm text-gray-500">{goal.user_id}</span>
            </div>
          ))}
          {goals.length === 0 && <p className="text-gray-500">Belum ada tujuan membaca.</p>}
        </div>
      </section>
    </main>
  )
}

import { withUserContext } from '../../../src/lib/db'
import { getUserClaims } from '../../../src/lib/supabase'

export default async function QuotesPage() {
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

  const quotes = await withUserContext(claims, async (tx) => {
    return tx.book_quotes.findMany({
      orderBy: { created_at: 'desc' },
    })
  })

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-4">
      <section className="flex w-full max-w-2xl flex-col items-center justify-center p-6">
        <h1 className="text-4xl font-bold tracking-tight">BookRate</h1>
        <p className="mt-4 text-xl text-gray-600">Daftar Quote Buku</p>
        <div className="mt-8 flex flex-col gap-2">
          {quotes.map((quote) => (
            <div
              key={quote.id}
              className="flex items-center justify-between p-3 bg-gray-50 rounded border border-gray-200"
            >
              <div>
                <span className="font-medium">{quote.content}</span>
                <p className="text-sm text-gray-500">Book ID: {quote.book_id}</p>
                {quote.page_number && (
                  <p className="text-sm text-gray-500">Halaman: {quote.page_number}</p>
                )}
              </div>
              <span className="text-sm text-gray-500">{quote.user_id}</span>
            </div>
          ))}
          {quotes.length === 0 && <p className="text-gray-500">Belum ada quote buku.</p>}
        </div>
      </section>
    </main>
  )
}

import { withUserContext } from '../../src/lib/db'

export default async function BooksPage() {
  const claims = {
    sub: 'user-123',
    role: 'authenticated',
  }

  const bookTags = await withUserContext(claims, async (tx) => {
    return tx.book_tags.findMany({
      orderBy: { created_at: 'desc' },
      take: 20,
    })
  })

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-4">
      <section className="flex w-full max-w-2xl flex-col items-center justify-center p-6">
        <h1 className="text-4xl font-bold tracking-tight">BookRate</h1>
        <p className="mt-4 text-xl text-gray-600">Daftar Tag Buku</p>
        <div className="mt-8 flex flex-col gap-2">
          {bookTags.map((tag) => (
            <div
              key={tag.id}
              className="flex items-center justify-between p-3 bg-gray-50 rounded border border-gray-200"
            >
              <span className="font-medium">{tag.tag_name}</span>
              <span className="text-sm text-gray-500">{tag.book_id}</span>
            </div>
          ))}
          {bookTags.length === 0 && <p className="text-gray-500">Belum ada tag buku.</p>}
        </div>
      </section>
    </main>
  )
}

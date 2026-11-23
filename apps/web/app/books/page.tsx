import { withUserContext } from '../../src/lib/db'
import { getUserClaims } from '../../src/lib/supabase'

export default async function BooksPage() {
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

  const bookTags = await withUserContext(claims, async (tx) => {
    return tx.book_tags.findMany({
      orderBy: { created_at: 'desc' },
      take: 20,
    })
  })

  async function deleteBookTag(formData: FormData) {
    const id = formData.get('id') as string

    await withUserContext(claims, async (tx) => {
      return tx.book_tags.delete({
        where: { id },
      })
    })
  }

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
              <div>
                <span className="font-medium">{tag.tag_name}</span>
                <span className="text-sm text-gray-500">{tag.book_id}</span>
              </div>
              <form action={deleteBookTag} method="POST">
                <input type="hidden" name="id" value={tag.id} />
                <button
                  type="submit"
                  onClick={() => window.confirm('Yakin ingin menghapus tag ini?')}
                  className="text-xs text-red-600 hover:text-red-800 font-medium"
                >
                  Hapus
                </button>
              </form>
            </div>
          ))}
          {bookTags.length === 0 && <p className="text-gray-500">Belum ada tag buku.</p>}
        </div>

        <div className="mt-8 flex flex-col gap-2">
          <a
            href="/books/categories"
            className="flex items-center justify-between p-3 bg-gray-50 rounded border border-gray-200"
          >
            <span className="font-medium">Kategori Buku</span>
            <span className="text-sm text-gray-500">Lihat semua kategori</span>
          </a>
          <a
            href="/books/goals"
            className="flex items-center justify-between p-3 bg-gray-50 rounded border border-gray-200"
          >
            <span className="font-medium">Tujuan Membaca</span>
            <span className="text-sm text-gray-500">Lihat semua tujuan</span>
          </a>
          <a
            href="/books/quotes"
            className="flex items-center justify-between p-3 bg-gray-50 rounded border border-gray-200"
          >
            <span className="font-medium">Quote Buku</span>
            <span className="text-sm text-gray-500">Lihat semua quote</span>
          </a>
        </div>
      </section>
    </main>
  )
}

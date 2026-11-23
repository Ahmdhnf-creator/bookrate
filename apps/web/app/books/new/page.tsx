import { withUserContext } from '../../../src/lib/db'
import { getUserClaims } from '../../../src/lib/supabase'

export default async function AddBookPage() {
  const session = await getUserClaims()

  if (!session) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center p-4">
        <section className="flex w-full max-w-md flex-col items-center justify-center p-6">
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

  async function createBook(formData: FormData) {
    const book_id = formData.get('book_id') as string
    const tag_name = formData.get('tag_name') as string

    await withUserContext(claims, async (tx) => {
      return tx.book_tags.create({
        data: {
          book_id,
          tag_name,
        },
      })
    })
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-4">
      <section className="flex w-full max-w-md flex-col items-center justify-center p-6">
        <h1 className="text-4xl font-bold tracking-tight">BookRate</h1>
        <p className="mt-4 text-xl text-gray-600">Tambah Buku Baru</p>
        <form action={createBook} className="mt-8 flex w-full flex-col gap-4" method="POST">
          <div className="flex flex-col gap-2">
            <label htmlFor="book_id" className="text-sm font-medium text-gray-700">
              Book ID
            </label>
            <input
              id="book_id"
              name="book_id"
              type="text"
              required
              className="rounded border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div className="flex flex-col gap-2">
            <label htmlFor="tag_name" className="text-sm font-medium text-gray-700">
              Tag
            </label>
            <input
              id="tag_name"
              name="tag_name"
              type="text"
              required
              className="rounded border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <button
            type="submit"
            className="rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            Simpan
          </button>
        </form>
        <a
          href="/books"
          className="mt-4 inline-flex items-center text-sm text-gray-600 hover:text-blue-600"
        >
          Kembali ke daftar
        </a>
      </section>
    </main>
  )
}

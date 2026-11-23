import { withUserContext } from '../../../src/lib/db'
import { getUserClaims } from '../../../src/lib/supabase'

export default async function BookDetailPage({ params }: { params: { id: string } }) {
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

  const book = await withUserContext(claims, async (tx) => {
    return tx.book_tags.findUnique({
      where: { id: params.id },
    })
  })

  if (!book) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center p-4">
        <section className="flex w-full max-w-2xl flex-col items-center justify-center p-6">
          <h1 className="text-4xl font-bold tracking-tight">BookRate</h1>
          <p className="mt-4 text-xl text-gray-600">Buku tidak ditemukan.</p>
          <a
            href="/books"
            className="mt-8 inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            Kembali ke daftar
          </a>
        </section>
      </main>
    )
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-4">
      <section className="flex w-full max-w-2xl flex-col items-center justify-center p-6">
        <h1 className="text-4xl font-bold tracking-tight">BookRate</h1>
        <p className="mt-4 text-xl text-gray-600">Detail Buku</p>
        <div className="mt-8 flex flex-col gap-2">
          <div className="flex items-center justify-between p-3 bg-gray-50 rounded border border-gray-200">
            <span className="font-medium">ID</span>
            <span className="text-sm text-gray-500">{book.id}</span>
          </div>
          <div className="flex items-center justify-between p-3 bg-gray-50 rounded border border-gray-200">
            <span className="font-medium">Book ID</span>
            <span className="text-sm text-gray-500">{book.book_id}</span>
          </div>
          <div className="flex items-center justify-between p-3 bg-gray-50 rounded border border-gray-200">
            <span className="font-medium">Tag</span>
            <span className="text-sm text-gray-500">{book.tag_name}</span>
          </div>
          <div className="flex items-center justify-between p-3 bg-gray-50 rounded border border-gray-200">
            <span className="font-medium">Dibuat pada</span>
            <span className="text-sm text-gray-500">{book.created_at.toString()}</span>
          </div>
        </div>
        <a
          href="/books"
          className="mt-8 inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          Kembali ke daftar
        </a>
      </section>
    </main>
  )
}

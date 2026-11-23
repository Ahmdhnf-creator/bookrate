import { withUserContext } from '../../../src/lib/db'
import { getUserClaims } from '../../../src/lib/supabase'

export default async function CategoriesPage() {
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

  const categories = await withUserContext(claims, async (tx) => {
    return tx.book_categories.findMany({
      orderBy: { name: 'asc' },
    })
  })

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-4">
      <section className="flex w-full max-w-2xl flex-col items-center justify-center p-6">
        <h1 className="text-4xl font-bold tracking-tight">BookRate</h1>
        <p className="mt-4 text-xl text-gray-600">Daftar Kategori Buku</p>
        <div className="mt-8 flex flex-col gap-2">
          {categories.map((category) => (
            <div
              key={category.id}
              className="flex items-center justify-between p-3 bg-gray-50 rounded border border-gray-200"
            >
              <span className="font-medium">{category.name}</span>
              <span className="text-sm text-gray-500">{category.slug}</span>
            </div>
          ))}
          {categories.length === 0 && <p className="text-gray-500">Belum ada kategori buku.</p>}
        </div>
      </section>
    </main>
  )
}

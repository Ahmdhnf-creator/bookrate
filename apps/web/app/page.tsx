import type { book_tags, PrismaClient } from '@prisma/client'
import { withUserContext } from '../src/lib/db'

export default async function HomePage() {
  // Contoh: mengambil data book_tags melalui Prisma dengan konteks user.
  // Dalam aplikasi nyata, sub dan role berasal dari Supabase Auth.
  const claims = {
    sub: 'user-123',
    role: 'authenticated',
  }

  const bookTags = await withUserContext(claims, async (tx: PrismaClient) => {
    return tx.book_tags.findMany({
      orderBy: { created_at: 'desc' },
      take: 10,
    })
  })

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-4">
      <section className="flex w-full max-w-2xl flex-col items-center justify-center p-6">
        <h1 className="text-4xl font-bold tracking-tight">BookRate</h1>
        <p className="mt-4 text-xl text-gray-600">Tag buku yang tersimpan:</p>
        <div className="mt-8 flex flex-col gap-2">
          {bookTags.map((tag: book_tags) => (
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

# BookRate — Development Roadmap

## Tujuan

Roadmap ini mengatur urutan pengembangan BookRate, Social Reading Platform dengan tagline **Read. Rate. Connect.**

## Target Rilis

- MVP web responsif dalam **30 hari kalender**, nyaman dipakai di desktop dan browser HP.
- **Hari 1** dimulai pada saat revisi dokumen ini disetujui dan Anda siap mulai mengeksekusi; tanggal kalender ditetapkan saat itu.
- Akhir pekan adalah hari non-kerja. **±20 hari kerja adalah asumsi perencanaan, bukan kepastian** (30 hari kalender ≈ 20–22 hari kerja tergantung hari mulai; tidak setiap hari produktif penuh).
- Aplikasi native Android/iOS **ditunda ke fase berikutnya**, di luar target 30 hari.

## Prinsip Pelaksanaan

- `docs/PRD.md` adalah sumber kebenaran untuk kebutuhan produk.
- Dokumen ini adalah sumber kebenaran untuk urutan task dan quality gate.
- Backend MVP: **Next.js server memakai Prisma Client** untuk akses data (PostgreSQL via Supabase), dengan **RLS** sebagai lapisan otorisasi database; autentikasi tetap **Supabase Auth**; mobile tetap memakai Supabase JS langsung tanpa Prisma Client; **custom API tersendiri tetap ditunda** (lihat bagian "Keputusan Backend MVP dan Penyesuaian Terhadap PRD"). Detail di `docs/architecture/0002-prisma-orm-backend.md`.
- Migrasi struktur database memakai **Prisma Migrate** untuk objek yang didukung Prisma; **file SQL ter-commit** (`db/scripts/`) tetap untuk RLS, policies, grants, triggers, functions, views, dan objek PostgreSQL khusus.
- Gate akses data: tidak ada tabel/view/RPC berisi data pengguna yang diakses client dengan publishable key sebelum **RLS default-deny + negative authorization test** per domain lulus. Gate ini menggantikan pola "backend selesai dulu, baru frontend".
- Ikuti workflow Superpowers untuk setiap task: pahami PRD, roadmap, dan kondisi repo; brainstorming; spesifikasi; rencana; review dan persetujuan; implementasi; verifikasi; dokumentasi; commit; lalu lanjut ke task berikutnya.
- Jangan mengubah scope produk, urutan task, atau keputusan teknis yang belum disepakati tanpa meminta persetujuan.
- Keputusan teknis yang belum ditetapkan harus dicatat sebagai **Open Decision**, bukan diasumsikan sudah disetujui.

## Scope MVP

### Masuk MVP (rilis 30 hari)

| FR | Scope MVP | Keterangan |
|---|---|---|
| FR-01 Authentication | Penuh: register, login, logout, reset password, verifikasi email | Supabase Auth |
| FR-02 User Profile | Subset: display name, username, bio, avatar, genre favorit, statistik; profil publik | Tanpa toggle visibilitas aktivitas/koleksi |
| FR-03 Book Search | Google Books (keyless dari client) + fallback Open Library | Risiko kuota, lihat Risiko Utama |
| FR-04 Book Detail | Metadata, rating agregat, total rating, community reviews | Tanpa rating distribution & popular reviewers (cut-list #2) |
| FR-05 Personal Library | Penuh: status baca, progress 0–100, tanggal, catatan | |
| FR-06 Rating & Review | Penuh: aturan bisnis (1 review aktif per buku, interval 0.5) | |
| FR-07 Follow | Follow/unfollow, followers, following | Tanpa mutual followers |
| FR-08 Home Feed | Following-only, 6 tipe aktivitas, pagination | |
| FR-09 Social Interaction | Like, unlike, comment, hapus comment sendiri | |
| FR-10 Notification | In-app: list + mark read; 3 tipe (NEW_FOLLOWER, REVIEW_LIKED, REVIEW_COMMENTED) | Tanpa push notification |
| FR-12 Privacy | Profil public by default melalui RLS | |

### Ditunda ke fase berikutnya

| Fitur | Alasan |
|---|---|
| Aplikasi native Android/iOS + integration testing mobile | Target: fase berikutnya setelah MVP |
| Push notification (FCM/APNs/web push) | Butuh infra platform; di luar 30 hari |
| FR-11 Search Readers & halaman discovery (suggested/popular/new/by genre) | Tidak termasuk DoD PRD; menghemat estimasi waktu |
| FR-12 lanjutan: report, block, admin moderation | Butuh admin console dan workflow review |
| FR-02 lanjutan: sembunyikan aktivitas/koleksi | Kompleksitas RLS ekstra; default publik memadai |
| FR-09 lanjutan: save review, share buku/review | Integrasi platform; nilai kecil untuk MVP |
| FR-07: mutual followers | Pemangkasan fokus MVP |
| FR-11: rekomendasi reader berbasis algoritma | Butuh volume data dan tuning |
| Seluruh daftar "Out of Scope for MVP" di PRD (messaging, chat, AI recs, paid, marketplace, dll.) | Tetap di luar, tidak berubah |

### Catatan DoD PRD

- Item DoD "Web dan mobile menggunakan data yang sama" tercapai setelah rilis mobile; pada MVP 30 hari item ini **ditunda** bersama mobile.
- Item DoD lainnya menjadi acuan uji pada Task 9, dengan penyesuaian scope di atas.

## Rencana 30 Hari Kalender

Asumsi perencanaan: mulai Senin, **±20 hari kerja (asumsi, bukan kepastian)** + 2 hari buffer. Akhir pekan pada Hari 6–7, 13–14, 20–21, dan 27–28 adalah hari non-kerja.

| # | Task | Estimasi (hari kerja) | Jendela (mulai Senin) | Verifikasi |
|---:|---|---:|---|---|
| 1 | Monorepo & Supabase Foundation (Task 01) | 2 | Hari 1–2 | V1: lint/typecheck/build/dev pass |
| 2 | Skema inti & RLS default-deny + workflow migrasi SQL | 3 | Hari 3–5 | V2: RLS negative test (gate akses client) |
| 3 | Web shell responsif + auth + profil | 3 | Hari 8–10 | V3: alur auth & profil di desktop + viewport HP |
| 4 | Book search, detail & personal library | 3 | Hari 11–12, 15 | V4: journey cari → simpan → progress |
| 5 | Rating, review, like, comment | 3 | Hari 16–18 | V5: 1 review/buku, interval 0.5 |
| 6 | Follow & home feed following-only | 2 | Hari 19, 22 | V6: feed hanya aktivitas yang diikuti |
| 7 | Notifikasi in-app | 1 | Hari 23 | V7: 3 tipe notifikasi terbit & terbaca |
| 8 | Hardening: audit RLS, validasi, rate limit, QA responsif | 1 | Hari 24 | V8: security gate |
| 9 | Uji journey kritis + deploy Vercel + dokumentasi | 2 | Hari 25–26 | V9: DoD-MVP lulus; aplikasi live |
| — | Buffer fleksibel | 2 (asumsi) | Hari 29–30 | Dialokasikan ke task yang meleset |

**Jika waktu terpakai melebihi rencana, pangkas berurutan:**

1. Polish/aksesibilitas lanjutan.
2. Rating distribution dan popular reviewers (FR-04).
3. Tipe notifikasi ke-3.

## Urutan Integrasi Fitur

Untuk setiap fitur MVP, ikuti urutan:

1. Database migration — struktur yang didukung Prisma via **Prisma Migrate**; RLS/policies/grants/triggers/functions/views/objek khusus via **file SQL ter-commit → Supabase Dashboard SQL Editor** (ADR 0002)
2. RLS policy + constraint + validasi (klien/RPC)
3. UI web responsif
4. Verifikasi (journey kritis + RLS negative test)
5. Dokumentasi

Catatan: tidak ada langkah pembuatan endpoint API terpisah — mengikuti keputusan backend MVP di bawah; akses data server memakai Prisma Client dalam transaksi berkonteks identitas (ADR 0002).

## Keputusan Backend MVP dan Penyesuaian Terhadap PRD

Untuk rilis MVP, akses data dari web memakai **Prisma Client di server Next.js** (PostgreSQL via Supabase) dengan **RLS** sebagai lapisan otorisasi; autentikasi memakai **Supabase Auth**; mobile (fase setelah MVP) memakai Supabase JS langsung dengan RLS yang sama tanpa Prisma Client; **custom API terpisah tetap ditunda**. ADR: `docs/architecture/0002-prisma-orm-backend.md`.

Ini adalah **penyesuaian scope** terhadap kebutuhan PRD §5 (NFR Scalability) *"Backend API terpisah secara logis dari frontend"*. Keputusan ini **tidak dinyatakan memenuhi sepenuhnya** kebutuhan lapisan API custom — validasi, otorisasi, dan rate limiting terpusat; versioning; titik kontrol tunggal — yang pada arsitektur ini tersebar di RLS, constraint, dan klien. Kebutuhan tersebut tetap tercatat sebagai **Open Decision** untuk tinjauan setelah MVP.

## Adopsi Prisma (2026-11-15)

Arsitektur database berpindah ke **PostgreSQL + Prisma** (Prisma Client server-side, Prisma Migrate + SQL hybrid) tanpa mengubah scope produk, gate, maupun security requirements. ADR: `docs/architecture/0002-prisma-orm-backend.md`.

Rencana implementasi bertahap (9 tahap, disimpan di `docs/superpowers/plans/2026-11-15-prisma-adoption-plan.md`):

1. Verifikasi kondisi database Supabase saat ini (read-only; tidak boleh mengasumsikan database kosong).
2. Finalisasi role database dan keamanan RLS (role runtime non-`BYPASSRLS`, role migrasi terpisah).
3. Penentuan lokasi `schema.prisma` dan Prisma Client dalam monorepo.
4. Strategi baseline dan urutan migration (Prisma Migrate + skrip SQL).
5. Integrasi Prisma dengan Next.js.
6. Konteks pengguna dalam transaksi Prisma.
7. Pengujian RLS melalui Prisma.
8. Verifikasi `006` (76 assertions) dan `007` (31 checks) tanpa mengurangi jumlah pemeriksaan.
9. Dokumentasi environment variables dan deployment.

Tahap ini berjalan **sebelum** mengandalkan Prisma pada task aplikasi; task 30 hari di atas tetap urutan product delivery. Bagian yang membutuhkan koneksi database ditandai UNVERIFIED sampai diverifikasi pada Tahap 1.

## Risiko Utama

- **Google Books keyless dari client (MVP):** kuota harian terbatas dan dapat terlampaui. Mitigasi: fallback Open Library, debounce pencarian, cache ringan. Proxy API tidak ditambahkan untuk MVP.
- **Estimasi meleset:** ±20 hari kerja adalah asumsi, bukan kepastian; buffer 2 hari dan cut-list berurutan adalah mekanisme penyesuaiannya.
- **Gate RLS:** Task 2 adalah prasyarat mutlak sebelum client mengakses data; tanpa verifikasi V2, task berikutnya tidak dimulai.

## Open Decisions

Keputusan berikut belum dianggap final dan perlu ditinjau sebelum implementasi yang bergantung padanya:

- ~~Pilihan dan bentuk backend final.~~ **Resolved untuk MVP:** Supabase langsung (PostgreSQL, Auth, Storage, RLS) dari client web; custom API ditunda; dicatat sebagai penyesuaian scope terhadap PRD, bukan pemenuhan penuh kebutuhan API terpisah.
- ~~Target deployment dan arsitektur hosting.~~ **Partially resolved:** Web = Next.js di Vercel; Mobile (fase setelah MVP) = Expo.
- ~~Migrasi database tanpa Supabase CLI.~~ **Resolved (diperbarui ADR 0002):** hybrid workflow — struktur yang didukung Prisma via **Prisma Migrate** (`DIRECT_URL`, role migrasi terpisah); RLS, policies, grants, triggers, functions, views, dan objek PostgreSQL khusus tetap lewat **file SQL ter-commit di `db/scripts/`** dijalankan manual via Supabase Dashboard SQL Editor; tanpa Supabase CLI, Docker, local Supabase, atau Edge Functions; status penerapan dicatat di `db/SCHEMA_STATE.md`.
- ~~Type generation database: ditunda sampai schema tersedia; hindari hand-maintain tipe DB berukuran besar.~~ **Resolved:** tipe query database dihasilkan oleh **Prisma Client** dari `schema.prisma` — tidak ada hand-maintain tipe DB.
- Keputusan teknis Prisma yang **masih terbuka** (terinci di ADR 0002 "Open Decisions"): versi Prisma mayor; bentuk role migrasi (`postgres` vs role dedicated); strategi baseline Prisma Migrate (bergantung verifikasi isi database hosted); mode pooler runtime; payload JWT claims; nilai `idle_in_transaction_session_timeout`. Rencana bertahap: `docs/superpowers/plans/2026-11-15-prisma-adoption-plan.md`.
- Peninjauan kembali kebutuhan lapisan API custom (PRD §5) setelah MVP.
- Kunci/penggunaan Google Books di fase pasca-MVP (untuk MVP: keyless dari client).
- Catatan penomoran (dicatat, bukan keputusan baru): dokumen Task 01 mempertahankan rujukan penomoran lama yang sudah disepakati — "Task 12/13" = scaffolding dan pengembangan web (dalam rencana ini: Task 3 dst.), "Task 12/14" = mobile (fase berikutnya).
- Detail teknis lain yang belum ditetapkan di PRD atau disetujui secara eksplisit.

## Estimasi Total

±20 hari kerja rencana + 2 hari buffer (**asumsi, bukan kepastian**) = ±22 hari kerja dalam 30 hari kalender, untuk satu developer yang fokus. Estimasi tidak mencakup waktu tunggu layanan eksternal.

## Aturan Memulai Task

Sebelum mengerjakan task, periksa `docs/PRD.md`, roadmap ini, dan kondisi repository saat ini. Jangan langsung mengimplementasikan task berikutnya tanpa menyelesaikan review dan persetujuan task yang sedang berjalan.

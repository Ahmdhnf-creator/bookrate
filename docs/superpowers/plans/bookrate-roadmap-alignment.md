# BookRate — Roadmap Alignment Audit

**Date:** 2026-11-06
**Sources read:** `docs/PRD.md` (414 baris, hash `6f1fe4f9…1313e`), `docs/ROADMAP.md` (127 baris, CRLF), `docs/architecture/0001-supabase-first-backend.md`, `docs/superpowers/plans/task-01-backend-project-setup.md` (induk, 554 baris), plans `task-02`…`task-08`, serta `git show HEAD:docs/ROADMAP.md` (75 baris — sumber Master 16 Task). Laporan verifikasi Task 8 **tidak ada di dalam repository** (hanya di sesi percakapan) — dicatat sebagai gap §12.
**Status:** Audit read-only; satu dokumen ini satu-satunya artefak baru.

---

## 1. Purpose & Scope

Menyelaraskan tiga lapis roadmap (Master 16 Task, Execution 30-Hari, Foundation 01–08) dengan PRD dan keputusan arsitektur terbaru (web-first, Supabase-first, Next.js, mobile deferred, custom API deferred, SQL manual via Dashboard, RLS default-deny + negative authorization test sebagai security gate).

Prinsip yang dipegang: **perubahan strategi implementasi ≠ penghapusan kebutuhan produk**. Setiap Master Task dan setiap FR/NFR PRD harus terpetakan — minimal dengan status MVP/Deferred/Partial beserta catatan scope. Konflik atau keputusan baru didokumentasikan sebagai *unresolved decision* — tidak diputuskan sendiri.

Di luar cakupan: implementasi fitur, edit PRD/ROADMAP/ADR/plan sebelumnya, commit, pengerjaan Execution Task berikutnya.

## 2. Roadmap Structure

Tiga lapis dengan ID terpisah untuk mencegah benturan nomor:

| Lapis | ID | Sumber | Peran |
|---|---|---|---|
| **A. Master Roadmap** | `Task 1`–`Task 16` | `git show HEAD:docs/ROADMAP.md` (roadmap awal, backend-first) | Daftar kebutuhan produk jangka panjang; penomoran & makna asli dipertahankan |
| **B. Execution Roadmap** | `Execution 1`–`Execution 9` (+ buffer) | `docs/ROADMAP.md` "Rencana 30 Hari Kalender" (aktif) | Urutan implementasi web MVP 30 hari kalender |
| **C. Foundation Tasks** | `FOUNDATION-01`–`FOUNDATION-08` | `docs/superpowers/plans/task-01-…` Step 1–8 + plan `task-02`…`task-08` | Pekerjaan fondasi yang **sudah dikerjakan**; tidak dicampur dengan Master maupun Execution |

**Aturan penamaan wajib:** "Task 8" dalam dokumen ini = **FOUNDATION-08 (Full Toolchain Verification)**, bukan Master Task 8 (Social System & Following). Rujukan legacy "Task 12/13" (web) dan "Task 12/14" (mobile) di plan/spec = **Master Task 12/13/14** — dipertahankan sesuai Catatan Penomoran ROADMAP (baris 118).

## 3. Master Roadmap (16 Tasks)

Sumber: `git show HEAD:docs/ROADMAP.md` — Phase 1 Backend (1–11), Phase 2 Frontend (12–15), Phase 3 Launch (16). Tidak ada Master Task yang dihapus atau dinomori ulang.

| Master Task | Kebutuhan/fungsi asli | Status dalam Execution Roadmap | Execution Task terkait | Status | Catatan perubahan scope |
|---|---|---|---|---|---|
| 1 | Backend Project Setup (3–4 hari) | Dieksekusi sebagai fondasi monorepo + toolchain sebelum fitur | Execution 1 (via FOUNDATION-01…08) | **MVP** | Scope-adjusted: setup monorepo + Supabase foundation, tanpa backend server custom |
| 2 | Database Architecture & Setup | Skema inti + RLS default-deny + workflow migrasi SQL | Execution 2 | **MVP** | Migrasi SQL manual via Dashboard (tanpa CLI); tanpa ORM |
| 3 | Authentication & Authorization | Auth & otorisasi pengguna | Execution 2 (RLS/authorization) + Execution 3 (auth UI) | **MVP** | Supabase Auth + RLS menggantikan middleware/endpoint custom; "authentication middleware" NFR dipenuhi oleh Supabase Auth (lihat §7) |
| 4 | User Profile & Privacy | Profil & privasi pengguna | Execution 3 | **Partial** | Profil publik penuh; **ditunda:** toggle sembunyikan aktivitas/koleksi (FR-02 lanjutan) |
| 5 | Book System & External API | Pencarian & metadata buku | Execution 4 | **Partial** | Google Books keyless dari client + fallback Open Library; **ditunda:** proxy API & kunci Google Books (Open Decision pasca-MVP); rating distribution & popular reviewers = cut-list #2 |
| 6 | Personal Library & Reading Progress | Koleksi & progres baca | Execution 4 | **MVP** | Penuh (status, progress 0–100, tanggal, catatan) |
| 7 | Rating & Review System | Rating & review | Execution 5 | **MVP** | Penuh (1 review aktif/buku, interval 0.5) |
| 8 | Social System & Following | Follow system | Execution 6 | **Partial** | Follow/unfollow/followers/following; **ditunda:** mutual followers |
| 9 | Activity Feed & Interaction | Feed aktivitas & interaksi | Execution 5 (like/comment) + Execution 6 (feed) | **Partial** | Feed following-only 6 tipe penuh; **ditunda:** save review, share, report/block (bagian FR-09/FR-12) |
| 10 | Notification, Discovery & Moderation | Notifikasi, discovery, moderasi | Execution 7 (notifikasi in-app) | **Partial** | 3 tipe in-app + mark read; **ditunda:** push notification, FR-11 discovery, admin moderation |
| 11 | Backend Testing, Security & API Finalization | Quality gate backend | **Diganti** gate per-domain: V2 (Execution 2), hardening (Execution 8), RLS exposure gate (ADR §RLS) | **Partial** | Task 11 terpisah sengaja dihapus dari ROADMAP aktif (diverifikasi FOUNDATION-07); kebutuhan pengujian/keamanan tetap — terdistribusi ke gate per-domain, bukan hilang |
| 12 | Frontend Project Setup & Design System | Fondasi frontend | Execution 3 (web shell responsif) | **MVP** | Web saja; design system disederhanakan jadi shell responsif; rujukan legacy "Task 12/13" |
| 13 | Web Development — Next.js | Aplikasi web | Execution 3–7 + 9 | **MVP** | Next.js di Vercel; seluruh FR MVP diimplementasikan di lapisan ini |
| 14 | Mobile Development — Expo | Aplikasi Android/iOS | **Tidak ada di 30 hari** — fase berikutnya | **Deferred** | Ditunda sampai web MVP selesai & waktu memungkinkan; rujukan legacy "Task 12/14" |
| 15 | API Integration & Cross-platform Testing | Integrasi API & uji lintas platform | Execution 9 (uji journey kritis web) | **Partial** | Integrasi = Supabase JS langsung (bukan API custom); **ditunda:** cross-platform testing mobile, integrasi custom API |
| 16 | Deployment & Launch | Deployment & rilis | Execution 9 (deploy Vercel + dokumentasi) | **Partial** | Web live di Vercel; **ditunda:** rilis app store mobile |

Tidak ada Master Task berstatus *Not Mapped* — seluruh 16 task terpetakan.

## 4. Execution Roadmap (30-Day MVP)

Diadopsi **apa adanya** dari `docs/ROADMAP.md` baris 65–76 (tidak ada roadmap baru yang disintesis):

| Execution | Task (aktual) | Estimasi | Jendela | Verifikasi | Status aktual |
|---|---|---:|---|---|---|
| 1 | Monorepo & Supabase Foundation (Task 01) | 2 | Hari 1–2 | V1: lint/typecheck/build/dev pass | **Selesai** (FOUNDATION-01…08; V1–V8 terverifikasi pada sesi FOUNDATION-08) |
| 2 | Skema inti & RLS default-deny + workflow migrasi SQL | 3 | Hari 3–5 | V2: RLS negative test (gate akses client) | Belum dimulai — **blocker berikutnya** |
| 3 | Web shell responsif + auth + profil | 3 | Hari 8–10 | V3: alur auth & profil desktop + viewport HP | Belum dimulai |
| 4 | Book search, detail & personal library | 3 | Hari 11–12, 15 | V4: journey cari → simpan → progress | Belum dimulai |
| 5 | Rating, review, like, comment | 3 | Hari 16–18 | V5: 1 review/buku, interval 0.5 | Belum dimulai |
| 6 | Follow & home feed following-only | 2 | Hari 19, 22 | V6: feed hanya aktivitas yang diikuti | Belum dimulai |
| 7 | Notifikasi in-app | 1 | Hari 23 | V7: 3 tipe notifikasi terbit & terbaca | Belum dimulai |
| 8 | Hardening: audit RLS, validasi, rate limit, QA responsif | 1 | Hari 24 | V8: security gate | Belum dimulai |
| 9 | Uji journey kritis + deploy Vercel + dokumentasi | 2 | Hari 25–26 | V9: DoD-MVP lulus; aplikasi live | Belum dimulai |
| — | Buffer fleksibel | 2 (asumsi) | Hari 29–30 | Dialokasikan ke task yang meleset | — |

Cut-list bila melebihi rencana (ROADMAP baris 78–82): (1) polish/aksesibilitas lanjutan, (2) rating distribution & popular reviewers, (3) tipe notifikasi ke-3.

Catatan penomoran: "Task 01" dalam tabel Execution 1 = unit pekerjaan plan induk (`task-01-backend-project-setup.md`), **bukan** Master Task 1.

## 5. Master-to-Execution Cross Reference

| Master | Execution | FOUNDATION terkait | Status |
|---|---|---|---|
| 1 Backend Project Setup | Execution 1 | FOUNDATION-01…08 | MVP (scope-adjusted) |
| 2 Database Architecture | Execution 2 | — | MVP |
| 3 Auth & Authorization | Execution 2, 3 | — | MVP |
| 4 Profile & Privacy | Execution 3 | — | Partial |
| 5 Book System & External API | Execution 4 | — | Partial |
| 6 Personal Library | Execution 4 | — | MVP |
| 7 Rating & Review | Execution 5 | — | MVP |
| 8 Social & Following | Execution 6 | — | Partial |
| 9 Feed & Interaction | Execution 5, 6 | — | Partial |
| 10 Notification/Discovery/Moderation | Execution 7 | — | Partial |
| 11 Backend Testing & Security | Execution 2 (V2), Execution 8, RLS gate ADR | FOUNDATION-03/07 (tooling) | Partial (pengganti: gate per-domain) |
| 12 Frontend Setup & Design System | Execution 3 | — | MVP |
| 13 Web Development Next.js | Execution 3–7, 9 | — | MVP |
| 14 Mobile Expo | — (fase pasca-MVP) | — | Deferred |
| 15 API Integration & Cross-platform | Execution 9 (web only) | — | Partial |
| 16 Deployment & Launch | Execution 9 (web Vercel) | — | Partial |

## 6. Foundation Tasks Status (01–08)

| ID | Task (plan di `docs/superpowers/plans/`) | Status | Bukti |
|---|---|---|---|
| FOUNDATION-01 | Monorepo & Supabase Foundation (`task-01-backend-project-setup.md` — BUILD Task 1) | **Selesai & terverifikasi** | package.json, turbo.json, .bun-version, .nvmrc, .gitignore, dev-placeholder, bun.lock; install OK |
| FOUNDATION-02 | TypeScript config (`task-02-typescript-config.md`, Opsi B) | **Selesai & terverifikasi** | `packages/config` + `files: []` + typecheck file; exit 0 |
| FOUNDATION-03 | Biome lint & format (`task-03-biome.md`, D3-1/D1-a) | **Selesai & terverifikasi** | biome.json schema 2.6.5 + `preset: recommended`; lint/format exit 0 (9 file) |
| FOUNDATION-04 | Reserve app dirs (`task-04-reserve-app-directories.md`) | **Selesai & terverifikasi** | `apps/{web,mobile}/.gitkeep` + `apps/README.md`; tanpa package.json |
| FOUNDATION-05 | Client-safe env example (`task-05-client-safe-env-example.md`, D1: blok Mobile dipertahankan) | **Selesai & terverifikasi** | `.env.example` 4 var kosong; grep rahasia exit 1; ignore rules terbukti |
| FOUNDATION-06 | README + ADR (`task-06-readme-and-adr.md`) | **Selesai & terverifikasi** | README additive (heading utuh); ADR 0001 Accepted, 7 seksi wajib |
| FOUNDATION-07 | ROADMAP reconciliation (`task-07-roadmap-reconciliation.md`) | **Selesai & terverifikasi** | 30-hari + penyesuaian scope ada; legacy Task 11/69–104 hilang; CRLF utuh; nol perubahan |
| FOUNDATION-08 | Full toolchain verification (`task-08-full-toolchain-verification.md`) | **Selesai & terverifikasi** | install/typecheck/lint/format/build/dev exit 0; audit lolos; status == baseline; **laporan hanya di sesi, tidak ada di repo (gap §12)** |

## 7. PRD Requirement Coverage

### Functional Requirements

| FR | Isi ringkas | MVP? | Penempatan | Keterangan |
|---|---|---|---|---|
| FR-01 Authentication | Register, login, logout, reset, verifikasi email, akun; email/username unik, hash, session aman | **MVP penuh** | Execution 3 (+Supabase Auth di Execution 2) | "Endpoint privat membutuhkan autentikasi" → Supabase Auth + RLS |
| FR-02 User Profile | Profil publik + edit + statistik + visibilitas | **Partial** | Execution 3 | MVP: display name, username, bio, avatar, genre, statistik, profil publik. **Deferred:** toggle sembunyikan aktivitas/koleksi |
| FR-03 Book Search | Cari judul/penulis/ISBN/publisher/genre; Google Books + Open Library | **MVP** | Execution 4 | Keyless dari client; fallback Open Library; risiko kuota (Risiko Utama) |
| FR-04 Book Detail | Metadata + rating agregat + reviews + distribution + popular reviewers | **Partial** | Execution 4 (sebagian di 5) | MVP: metadata, rating agregat, total, community reviews. **Cut-list #2:** distribution & popular reviewers |
| FR-05 Personal Library | Status baca, progress, tanggal, catatan | **MVP penuh** | Execution 4 | |
| FR-06 Rating & Review | 0.5–5.0 interval 0.5, 1 review aktif/buku, edit/hapus | **MVP penuh** | Execution 5 | |
| FR-07 Follow System | Follow/unfollow/followers/following; aturan follow | **Partial** | Execution 6 | **Deferred:** mutual followers |
| FR-08 Home Feed | Following-only, 6 tipe aktivitas, pagination | **MVP penuh** | Execution 6 | |
| FR-09 Social Interaction | Like, comment, hapus comment; save, share, report, block | **Partial** | Execution 5 (like/comment) | **Deferred:** save review, share, report, block |
| FR-10 Notification | 5 jenis; list, mark read, mark all | **Partial** | Execution 7 | MVP: 3 tipe in-app + mark read (+mark all mengikuti). **Deferred:** push; `NEW_COMMENT_REPLY` & `READING_MILESTONE` (ditandai *future* di PRD) |
| FR-11 Search Readers | Cari reader + halaman discovery + rekomendasi algoritmik | **Deferred** | — (fase pasca-MVP) | Bukan item DoD PRD; menghemat estimasi (ROADMAP baris 48, 53) |
| FR-12 Privacy & Moderation | Public default, sembunyikan, block, report, admin moderation | **Partial** | Execution 2 (RLS public-by-default) | MVP: profil public by default via RLS. **Deferred:** report/block/admin moderation, sembunyikan aktivitas/koleksi |

### Non-Functional Requirements

| NFR | Kelompok | Status | Penempatan / catatan |
|---|---|---|---|
| Responsif, pagination feed, debounce search, image optimization, index DB | Performance | **MVP** | Execution 2 (index), 3–6 (UI & pagination); cover optimization via Next.js |
| Password hashing aman, session aman, auth | Security | **MVP** | Supabase Auth (menggantikan middleware custom — dipenuhi lewat penyedia) |
| Authorization checks | Security | **MVP** | RLS default-deny + negative test (gate Execution 2; ulang per-domain; audit Execution 8) |
| Input validation | Security | **MVP** | Constraint DB (Execution 2) + validasi klien (Execution 3–7) + audit (Execution 8) |
| Rate limiting | Security | **Partial** | Best-effort di MVP (Execution 8); **rate limiting terpusat** = bagian kebutuhan API custom → Open Decision pasca-MVP |
| Proteksi SQL injection | Security | **MVP** | Parameterisasi via Supabase JS; tanpa query string klien |
| Secrets tidak masuk repo | Security | **MVP** | FOUNDATION-05 (`.env.example` tanpa rahasia; `.gitignore` benar) |
| **Backend API terpisah secara logis** | Scalability | **Partial — scope adjustment** | **Bukan terpenuhi penuh.** Custom API deferred; tercatat eksplisit di ROADMAP §Keputusan Backend (baris 96–100), ADR §Decision, dan Open Decision baris 116 (tinjauan ulang setelah MVP) |
| Relasi terstruktur; feed data terpisah; rekomendasi berkembang tanpa ubah fondasi | Scalability | **MVP** | Skema Execution 2 (feed sebagai tabel aktivitas) |
| Desktop/tablet/mobile-browser responsif | Compatibility | **MVP** | Execution 3 + QA responsif Execution 8 |
| Android, iOS | Compatibility | **Deferred** | Master 14 — fase pasca-MVP |
| Semantic, keyboard nav, label, kontras | Accessibility | **MVP (dasar) + Partial** | Dasar di MVP; polish lanjutan = cut-list #1 |

**Requirement tanpa tempat implementasi:** tidak ada yang *Not Mapped*. Dua item hanya berstatus keputusan/penundaan terdokumentasi: (a) angka target §6 Metrics — menunggu baseline beta (bukan task implementasi); (b) item DoD "Web dan mobile menggunakan data yang sama" — ikut tertunda bersama mobile (ROADMAP baris 58). **Perlu keputusan pengguna:** lihat §12 (provisi project Supabase, dll).

**Out of Scope PRD §7** (10 item: messaging, chat, AI recs, paid, marketplace, dst.) — tetap di luar, tidak berubah (ROADMAP baris 54).

**DoD PRD §8 (12 item):** 11 item diuji pada Execution 9 dengan penyesuaian scope; 1 item (web & mobile data sama) deferred bersama mobile.

## 8. MVP vs Deferred Features

**Masuk MVP 30 hari** (ROADMAP §Masuk MVP, baris 26–40): FR-01 penuh; FR-02 subset; FR-03; FR-04 subset; FR-05 penuh; FR-06 penuh; FR-07 subset; FR-08 penuh; FR-09 subset (like/comment); FR-10 subset (3 tipe in-app); FR-12 subset (public-by-default RLS).

**Deferred ke fase berikutnya** (ROADMAP §Ditunda, baris 42–54): app native Android/iOS + integration testing mobile; push notification; FR-11 seluruhnya; FR-12 lanjutan (report/block/admin); FR-02 lanjutan (visibility toggle); FR-09 lanjutan (save/share); FR-07 mutual followers; rekomendasi reader algoritmik; seluruh Out of Scope PRD §7.

**Cut-list bila overrun** (berurutan): polish/aksesibilitas → rating distribution & popular reviewers → tipe notifikasi ke-3.

## 9. Architecture & Security Alignment

### Konsistensi arsitektur (dicek silang PRD ↔ ROADMAP ↔ ADR ↔ plan)

| Keputusan | PRD | ROADMAP | ADR | Plan/task | Konsisten? |
|---|---|---|---|---|---|
| Supabase-first (Auth+Postgres+Storage+RLS) | §5/§4 (butuh auth/db) | baris 18, 98, 112 | §Decision | FOUNDATION-01…06 | Ya |
| Web-first; Next.js | §3 Web App | baris 9, 113 | §Decision & Context | Execution 3–9 | Ya |
| Mobile deferred | §3 Mobile App (kebutuhan tetap) | baris 12, 46, 113 | §Decision (tidak memblokir web MVP) | Master 14 deferred | Ya — kebutuhan tidak dihapus, hanya dijadwalkan ulang |
| Custom API deferred | §5 Scalability menuntut API terpisah | baris 18, 98–100, 116 | §Decision (scope adjustment, bukan pemenuhan penuh) | — | Ya, **dengan penanda eksplisit:** deferred = **scope adjustment**, bukan klaim kebutuhan API PRD terpenuhi |
| SQL migration manual via Dashboard | — | baris 88, 114 | §Decision | FOUNDATION (workflow) | Ya |
| Type generation deferred | — | baris 115 (Open Decision) | tidak disebut (di luar isi ADR) | — | Ya — tercatat sebagai Open Decision, bukan asumsi |
| Google Books keyless MVP | FR-03 (Google Books API) | baris 32, 104, 117 | tidak disebut | — | Ya — keyless = kondisi MVP; kunci = Open Decision pasca-MVP |
| RLS default-deny + negative authz test = gate | §4/§5 security | baris 19 (gate), 106 (prasyarat) | §RLS Exposure Gate | FOUNDATION (spec), Execution 2 V2 | Ya |

### Security & quality gate untuk arsitektur Supabase-first

| Kontrol | Wajib MVP? | Penempatan |
|---|---|---|
| RLS default-deny per domain | **Wajib — blocker absolut** | Execution 2 (V2); tidak boleh ada client akses data sebelum lulus (ROADMAP baris 19, 106) |
| Negative authorization test per domain data | **Wajib** | Execution 2 (V2 gate) + per-fitur Execution 3–7 + audit Execution 8 |
| User tidak baca/ubah data user lain | **Wajib** | Ikut negative test di atas; bagian DoD §8 "Authorization dan privacy rules telah diuji" |
| Validasi input | **Wajib** | Constraint DB Execution 2; validasi klien Execution 3–7; audit Execution 8 |
| Integritas relasi DB | **Wajib** | FK/unique/check di migration Execution 2 |
| Error handling | **Wajib** | Pola error aman (tanpa bocoran data) — Execution 3–7 + audit Execution 8 |
| Rate limiting | **Wajib (bentuk MVP)** | Best-effort MVP (Execution 8); bentuk terpusat via API custom = deferred/Open Decision |
| Pagination & performa query | **Wajib** | Index Execution 2; pagination feed Execution 6; debounce Execution 4 |
| Pengujian integrasi Supabase | **Wajib** | RLS negative test (Execution 2) + journey kritis (Execution 9) |
| Push infra, moderation console, API versioning | Deferred | Fase pasca-MVP |

**Catatan Task 11:** Master Task 11 (Backend Testing, Security & API Finalization) sebagai gate terpisah **memang sudah digantikan** oleh kombinasi V2 (Execution 2) + Execution 8 + RLS Exposure Gate ADR — konsisten dengan penghapusan pola "backend selesai dulu" yang diverifikasi FOUNDATION-07. Tidak ada gate keamanan yang hilang; hanya bentuknya yang terdistribusi per-domain.

## 10. Dependencies & Recommended Sequence

**Sudah selesai:** FOUNDATION-01…08 (termasuk verifikasi toolchain penuh). Execution 1 efektif terpenuhi isi-nya; sisa proses = commit/otorisasi (lihat §12).

**Belum dimulai:** Execution 2–9.

**Blocker:**
- **Execution 2 adalah blocker absolut** untuk semua pekerjaan berikutnya (gate RLS; ROADMAP baris 106).
- Prasyarat praktis Execution 2: **project Supabase hosted yang tersedia** (akun/URL/key) + keputusan penerapan workflow migrasi SQL manual — membutuhkan pengguna.

**Paralel:** sebelum Execution 2 lulus tidak ada pekerjaan produk yang aman dijalankan. Setelah V2 lulus, urutan Execution 3→9 bersifat sekuensial menurut dependensi fitur (auth → buku → review → social → notifikasi → hardening → rilis); penyiapan non-blokir yang boleh berjalan paralel: penyiapan proyek Vercel & domain (untuk Execution 9) — tanpa mengubah file.

**Langkah berikutnya setelah FOUNDATION-08:** **Execution Task 2 — "Skema inti & RLS default-deny + workflow migrasi SQL"** (Hari 3–5, verifikasi V2), setelah prasyarat Supabase dan persetujuan workflow diperoleh.

## 11. Next Task Recommendation

**Rekomendasi: Execution 2 (Skema inti & RLS default-deny + workflow migrasi SQL).**

Alasan: (1) urutan resmi ROADMAP; (2) blocker absolut untuk Execution 3+ karena gate akses data; (3) seluruh fondasi toolchain sudah terverifikasi; (4) seluruh FR MVP bergantung pada skema + keamanan dasar ini. Bentuk pengerjaan mengikuti workflow Superpowers (brainstorm → spec → plan → persetujuan → implement → verifikasi) dan **belum boleh dimulai tanpa persetujuan pengguna** — terutama karena membutuhkan keputusan prasyarat §12.

## 12. Risks, Gaps & Unresolved Decisions

**Gaps:**
1. Laporan verifikasi FOUNDATION-08 tidak tersimpan di repository (hanya sesi percakapan) — pertimbangkan arsip laporan bila diperlukan bukti audit.
2. Seluruh perubahan Task 1–7 (termasuk restructure ROADMAP dan PRD working-tree) **belum di-commit**; HEAD masih `0972869`. Keputusan commit = wewenang pengguna per workflow.
3. Master Task 15 "API Integration" hanya terpetakan sebagian (Supabase JS) — integrasi custom API tak punya slot sampai keputusan pasca-MVP.

**Risiko (dari ROADMAP, tidak berubah):** kuota Google Books keyless; estimasi meleset (buffer + cut-list); gate RLS sebagai prasyarat mutlak.

**Unresolved decisions (butuh persetujuan pengguna — tidak diputuskan di audit ini):**
1. **Prasyarat Execution 2:** penyediaan project Supabase hosted (URL + publishable key + akses Dashboard untuk SQL Editor) dan konfirmasi workflow migrasi manual (ROADMAP baris 114 masih berstatus Open Decision).
2. **Type generation:** tetap ditunda sampai schema tersedia (ROADMAP baris 115) — perlu konfirmasi saat skema pertama dibuat.
3. **Peninjauan lapisan API custom** setelah MVP (ROADMAP baris 116) — termasuk rate limiting terpusat, versioning, titik kontrol tunggal.
4. **Kunci Google Books** untuk fase pasca-MVP (ROADMAP baris 117).
5. **Commit plan kerja saat ini** (PRD/ROADMAP/README/ADR/fondasi belum ter-commit).
6. Pelaksanaan **Execution 1 sebagai "Hari 1–2"** — apakah pekerjaan fondasi yang sudah ada dihitung masuk jendela tersebut atau jendela dimulai saat Execution 2 (bookkeeping jadwal, bukan keputusan teknis).

Tidak ditemukan konflik keputusan arsitektur baru yang tidak tercakup di atas; seluruh perbedaan PRD ↔ implementasi sudah terdokumentasi sebagai scope adjustment, bukan perlu perbaikan sepihak.

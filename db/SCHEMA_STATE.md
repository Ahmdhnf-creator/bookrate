# SCHEMA STATE — status penerapan skrip (pengganti migration tracking)

> Catatan: skrip direvisi pasca-audit keamanan 2026-11-08 **sebelum aplikasi pertama** (belum ada baris `applied`).
>
> Catatan ADR 0002 (2026-11-15): struktur yang didukung Prisma beralih ke **Prisma Migrate**; tabel di bawah tetap status skrip SQL untuk objek keamanan/objek khusus. **Riwayat migrasi Prisma (`prisma_migrations`) dilacak terpisah** dan dicatat di sini setelah baseline disetujui. Isi database hosted **belum diverifikasi** — jangan menganggap kosong.

Workflow: jalankan skrip urut 001→007 via Supabase Dashboard SQL Editor, lalu tandai di sini.
Kolom `applied` = skrip sukses dijalankan; `verified` = blok `-- VERIFY`/tes lolos.

| Skrip | applied (tanggal) | verified (tanggal) | Catatan |
|---|---|---|---|
| 001_enums.sql | — | — | pending |
| 002_identity_books.sql | — | — | pending |
| 003_library.sql | — | — | pending |
| 004_reviews_social.sql | — | — | pending |
| 005_activity_notifications.sql | — | — | pending |
| 006_negative_tests.sql | — | — | pending; dua profil pertama menurut join_date dipakai sebagai A dan B |
| 007_verify_schema.sql | — | — | pending; gate V2 |

## Log perubahan manual (jangan ada — hanya untuk catatan insidental)

| Tanggal | Oleh | Perubahan di luar skrip | Tindak lanjut |
|---|---|---|---|
| — | — | — | — |

## Gate V2 (Execution Task 2 selesai)

- [ ] 001–007 applied & verified (di atas).
- [ ] 006: `ALL NEGATIVE TESTS PASSED` (76 pemeriksaan).
- [ ] 007: `VERIFY SCHEMA: ALL 31 CHECKS PASSED`.
- [ ] Dilaporkan ke pengguna; Execution 3 belum dimulai.

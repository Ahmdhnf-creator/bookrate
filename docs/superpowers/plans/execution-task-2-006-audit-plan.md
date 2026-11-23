# PLAN — Audit Task 2 (006 Negative Tests) · 29/76 Gagal

> PLAN SAJA. Tidak ada perubahan file, tidak ada SQL, tidak ada Supabase.

## A. TEMUAN KRITIS

### A-1 (BLOCKER) — `db/scripts/006_negative_tests.sql` TRUNCATED
- `wc -l` = **113 baris** (seharusnya ≈ 617). File mulai di tengah `set_config` SESI B (V18) — **tidak ada `begin;`, harness, fixture, SESI A/B/A-kembali/V, K01-K03, N01-N04, S01**.
- `grep -c "^begin;"` = 0, `grep -c "^rollback;"` = 1, `grep -c "_t006_expect"` = 17 (seharusnya 76), harness tables = 0, fixture books = 0.
- Semua script lain utuh: 001=38, 002=173, 003=101, 004=441, 005=583, 007=210.
- **Sumber pemulihan yang sah = TIDAK ADA di repo.** Bundle snapshot basi (versi 39-test lama: 47 expects, tanpa SESI V/ANON). Plan revisi hanya berisi langkah-langkah (tanpa harness/fixture penuh). Git reflog = clone dari remote (tanpa riwayat 006).
- **Akar masalah 29 kegagalan = file truncated, bukan bug RLS/grant.** Investigasi (JWT valid, `auth.uid()` cocok, `library_entry_notes` sukses, RLS probe terpisah sukses) mengindikasikan file utuh — kontradiksi yang hanya terjelaskan oleh truncated file.

### A-2 (MAJOR) — Policy `activities` di 005 = `activities_select_following`
- Aktual `005_activity_notifications.sql:86-108`: `activities_select_following` — `actor_id = auth.uid() OR exists(follows WHERE follower_id = auth.uid() AND following_id = activities.actor_id)`.
- Dampak: AN05 (`count(*) >= 1 from activities` sebagai anon) bisa gagal 42501; B12 (feed B) bisa gagal bila A tidak diikuti B.
- **Koreksi temuan sebelumnya:** rencana §1A-A mengatakan "feed tetap publik", tapi **PRD FR-08 (252) & 272 & 409** menyatakan "Home feed hanya menampilkan aktivitas dari pengguna yang diikuti" → policy di 005 KONSISTEN dengan PRD; spesifikasi & keputusan yang kontradiksi adalah yang perlu diperbaiki. Lihat `execution-task-2-006-recovery-plan.md` §D.
- BUKTI DB (bukan bug harness): 002 grants 4+6, 003 library 4 policy + notes tanpa SELECT, 004 reviews 3 policy + 12 total + 2 view (kedua security_invoker=on), 005 triggers 5 + definer — semua sesuai spesifikasi, **kecuali policy activities**.

## B. PEMBEDAAN BUG
| Jenis | Temuan | Status |
|---|---|---|
| Bug harness | 006 truncated (A-1) | **Ada — akar masalah** |
| Bug konfigurasi DB | Policy activities ≠ spesifikasi (A-2) | **Ada — perlu keputusan** |
| Bug RLS/grant sesuai spesifikasi | Tidak ditemukan | Tidak ada |

## C. REKOMENDASI (tanpa eksekusi)
1. **Pulihkan 006 lengkap** (≈617 baris: begin → harness → fixture → SESI A/B/A-kembali/V/ANON → POSTGRES → RINGKASAN → rollback) dari sumber yang diotorisasi pengguna — repo lokal tidak memilikinya.
2. **Putuskan policy activities**: (a) ganti ke `using (true)` sesuai spesifikasi (mengubah 005), ATAU (b) perbarui spesifikasi & test (AN05/B12) — keputusan ada di pengguna.
3. Setelah 006 utuh + keputusan A-2: re-run 006, target kembali 76/76.

## D. BATASAN
- Tidak mengubah 001-005, 007, PRD, ROADMAP, ADR, SCHEMA_STATE, bundle.
- Tidak mengurangi assertion (target 76 tetap).
- Tidak commit/push; tidak mulai Task 3.

## E. STATUS
- File rencana ini = satu-satunya file baru. Nol perubahan file lain (cek `git status`).
- Menunggu persetujuan pengguna sebelum Build.
# RECOVERY PLAN — Task 2: 006 Negative Tests (29/76 Gagal)

> PLAN ONLY. Tidak ada perubahan file, tidak ada SQL, tidak ada Supabase.

## A. STATUS
**BLOCKED** — sumber pemulihan 006 lengkap (76 pemeriksaan) TIDAK DITEMUKAN di repo.

## B. TEMUAN KRITIS

### B-1 (BLOCKER) — `006_negative_tests.sql` truncated
- `wc -l` = 113 baris (seharusnya ~617). File mulai di tengah `set_config` SESI B.
- `grep -c "^begin;"` = 0, `grep -c "_t006_expect"` = 17 (seharusnya 76), harness tables = 0, fixture books = 0.
- Hilang: begin, harness, fixture, SESI A, SESI B, SESI A-kembali, SESI V, K01-K03, N01-N04, S01.
- File lain utuh: 001=38, 002=173, 003=101, 004=441, 005=583, 007=210.

### B-2 (MAJOR) — Policy `activities` = `activities_select_following`, bukan `using (true)`
- `005:86-108`: `actor_id = auth.uid() OR exists(follows WHERE follower_id=auth.uid() AND following_id=activities.actor_id)`.
- Dampak: AN05/B12 (activity feed) bisa gagal bila A tidak diikuti B.

### B-3 (MAJOR) — Grant `activities` & `profile_stats` ke anon
- `005:66`: `grant select on public.activities to authenticated` — TANPA anon.
- `004:392`: `grant select on table public.profile_stats to anon, authenticated` — ADA anon.
- Dampak: AN05 (`count(*) >= 1 from activities` sebagai anon) → 42501.

### B-4 (OBSERVATION) — `auth.uid()` NULL di RLS
- Semua INSERT policies pakai `with check (user_id = (select auth.uid()))`. Jika NULL → 42501. Operator klaim probe membuktikan auth.uid() bekerja, tapi probe kemungkinan dijalankan sebagai postgres (bypass RLS) → tidak membuktikan evaluasi RLS.

## C. KONFIGURASI DB (002-005) — UNTUH
- 002: 4 policy + 6 grant, benar.
- 003: 4 policy, notes tanpa SELECT, library_entry_notes definer, benar.
- 004: 12 policy (reviews 3, likes 3, comments 3, follows 3), 2 view (book_rating_summary + profile_stats, KEDUANYA security_invoker=on), grant anon ke 2 view, 7 index, benar.
- 005: 5 fungsi definer, 3 policy (activities_select_following, notifications_select_own, notifications_update_own), 7 trigger, grant notif 8 kolom + update(read), benar KECUALI policy activities.

## D. KEPUTUSAN PRODUK (otoritatif)
- **PRD FR-08 (252):** "Home feed hanya menampilkan aktivitas dari pengguna yang diikuti."
- **PRD 272:** "Feed tidak menampilkan aktivitas dari pengguna yang tidak diikuti."
- **PRD 409:** "Home feed menampilkan aktivitas following."
- → Policy `activities_select_following` di 005 KONSISTEN dengan PRD.
- → Spesifikasi "publik" & keputusan "feed tetap publik" di rencana §1A-A KONTRAKSI. **Perbaiki spesifikasi, bukan policy.**

## E. OPSI
**Opsi A (feed following — rekomendasi):** policy tetap; perbarui spesifikasi §1A-A + test AN05/B12. Keamanan: privasi lebih ketat, sesuai PRD.
**Opsi B (feed publik):** ganti policy ke `using (true)` di 005; perbarui PRD. Keamanan: feed publik (semua lihat aktivitas siapa pun).

## F. RENCANA PEMULIHAN 006
1. Sumber sah (operator): clipboard/history SQL Editor atau re-create dari (a) harness+fixture+SESI A/B/A-kembali+POSTGRES+RINGKasAN di bundle lama (47 expects) + (b) potongan task-step di revision plan (K/N/S/V/AN/P06-P07).
2. Verifikasi 76 expects, 8 sesi, begin/rollback, harness tables.
3. Putuskan policy activities (E).
4. Re-run 006 → target 76/76.

## G. KEPUTUSAN YANG BUTUH PERSETUJUAN
1. Sumber pemulihan 006.
2. Opsi A atau B untuk policy activities.
3. Perbarui spesifikasi §1A-A sesuai opsi terpilih.

## H. BATASAN
Tidak ubah 001-005, 007, PRD, ROADMAP, ADR, SCHEMA_STATE, bundle. Tidak kurangi assertion (76 tetap). Tidak commit/push. Tidak mulai Task 3.

## I. INTEGRITAS
Hanya file rencana ini yang baru. Nol perubahan file lain (cek git status). 006 masih 113 baris (tidak diubah).
# FINAL RECOVERY PLAN — Execution Task 2 (006 Negative Tests)

> PLAN ONLY. Tidak ada perubahan file, tidak ada SQL, tidak ada Supabase, tidak ada commit.

## A. STATUS
**BLOCKED** — sumber pemulihan 006 lengkap (76 pemeriksaan) TIDAK DITEMUKAN di repo. Rekonstruksi dirancang dari bundle lama (39 test) + 37 test baru di revision plan.

## B. GIT INTEGRITY AUDIT (FASE 1)
- `git status --short --untracked-files=all`: 3 file modified (`README.md`, `docs/PRD.md`, `docs/ROADMAP.md`), sisanya untracked.
- `git diff --cached`: kosong. `git stash list`: kosong. `git log --oneline --all`: 2 commit (0972869, 169a559 clone).
- **Klasifikasi:**
  - Pekerjaan sebelumnya: `README.md` (+40 baris Task 06), `docs/PRD.md` (414/414 = whitespace-only, CRLF normalization), `docs/ROADMAP.md` (94/43, Task 07).
  - Audit terbaru: 0 file diubah oleh audit ini (hanya 2 rencana baru, mtime 09:27).
  - Tidak diketahui asalnya: TIDAK ADA. Semua file untracked (`db/`, `docs/superpowers/plans/*`, `apps/`, `packages/`, `scripts/`, config) tidak pernah di-commit.
- **Dipertahankan (tidak diubah):** PRD hash `6f1fe4f9…1313e`, ROADMAP 127 CR, 001–005 & 007 utuh (38/173/101/441/583/210), `006_negative_tests.sql` masih 113 baris (tidak diubah).
- **NEEDS REVIEW:** tidak ada.

## C. RECONSTRUCTION (FASE 2)

### C-1. Sumber rekonstruksi
- **Fondasi (39 test lama):** `db/AUDIT_REVIEW_BUNDLE.md` — harness (begin/drop/create tables/4 helper/grants) + fixture (4 books, 2 library_entries, 1 review, 7 keys) + SESI A (A01–A12) + SESI B (B01–B13) + SESI A KEMBALI (A13–A21) + POSTGRES (P01–P05) + RINGKASAN + rollback. **Bukan bukti 76 tersedia** — hanya fondasi.
- **37 test baru:** `execution-task-2-security-revision-plan.md` Step 3–9 — K01–K03 (SESI A), N04 (SESI B), N01–N03 + S01 (SESI A KEMBALI), SESI V (V01–V18), SESI ANON (AN01–AN08), K04 + P06 + P07 (POSTGRES).
- **Klaim 76:** `execution-task-2-database-plan.md:143` & `security-revision-plan.md:731`. **Tidak ada file 76-test di repo.**

### C-2. Struktur rekonstruksi
```
begin;
[harness: drop/create _t006_results/_t006_ids, 4 helper, grants]
[fixture: 4 books + 2 library_entries + 1 review + 7 keys (tambah book_v1/book_v2)]
SESI A (A01–A12 + K01–K03)
SESI B (B01–B13 + N04)
SESI A KEMBALI (A13–A21 + N01–N03 + S01)
SESI V (V01–V18)
SESI ANON (AN01–AN08)
POSTGRES (P01–P05 + K04 + P06 + P07)
RINGKASAN + rollback;
```

### C-3. Matriks rekonstruksi 76 assertion

**Sesi A (pemilik A) — 15 test (A01–A12 + K01–K03):**
| ID | Tujuan | Expected | Source | Confidence |
|---|---|---|---|---|
| A01 | notes terbaca via fungsi milik sendiri | true (RAHASIA-A) | bundle SESI A | Confirmed |
| A02 | notes TIDAK terbaca via SELECT tabel (hak kolom) | expect_fail 42501 | bundle SESI A | Confirmed |
| A03 | entry privat sendiri terlihat | count=1 | bundle SESI A | Confirmed |
| A04 | UPDATE notes sendiri diizinkan | expect_pass | bundle SESI A | Confirmed |
| A05 | notes hasil UPDATE terbaca via fungsi | true (RAHASIA-BARU) | bundle SESI A | Confirmed |
| A06 | INSERT activities langsung DITOLAK | expect_fail 42501 | bundle SESI A | Confirmed |
| A07 | INSERT notifications langsung DITOLAK | expect_fail 42501 | bundle SESI A | Confirmed |
| A08 | UPDATE profil orang lain TIDAK berpengaruh | expect_0rows | bundle SESI A | Confirmed |
| A09 | rating di luar interval CHECK ditolak | expect_fail 23514 | bundle SESI A | Confirmed |
| A10 | kontrol positif: insert review valid | expect_pass | bundle SESI A | Confirmed |
| A11 | review ganda pada buku sama DITOLAK | expect_fail 23505 | bundle SESI A | Confirmed |
| A12 | follow diri sendiri DITOLAK | expect_fail 23514 | bundle SESI A | Confirmed |
| K01 | UPDATE books DITOLAK (insert-only) | expect_fail 42501 | revision Step 3 | Confirmed |
| K02 | kontrol positif: INSERT buku baru | expect_pass | revision Step 3 | Confirmed |
| K03 | jalur upsert ON CONFLICT DO NOTHING | expect_pass | revision Step 3 | Confirmed |

**Sesi B (pihak lain) — 14 test (B01–B13 + N04):**
| ID | Tujuan | Expected | Source | Confidence |
|---|---|---|---|---|
| B01 | notes milik A TIDAK terbaca via SELECT | expect_fail 42501 | bundle SESI B | Confirmed |
| B02 | entry PRIVATE milik A TIDAK terlihat | count=0 | bundle SESI B | Confirmed |
| B03 | entry PUBLIC milik A terlihat | count=1 | bundle SESI B | Confirmed |
| B04 | UPDATE entry PRIVATE milik A TIDAK berpengaruh | expect_0rows | bundle SESI B | Confirmed |
| B05 | UPDATE review milik A TIDAK berpengaruh | expect_0rows | bundle SESI B | Confirmed |
| B06 | DELETE review milik A TIDAK berpengaruh | expect_0rows | bundle SESI B | Confirmed |
| B07 | kontrol positif: like review aktif A oleh B | expect_pass | bundle SESI B | Confirmed |
| B08 | kontrol positif: comment review aktif A oleh B | expect_pass | bundle SESI B | Confirmed |
| B09 | kontrol positif: follow A oleh B | expect_pass | bundle SESI B | Confirmed |
| B10 | INSERT notifications langsung DITOLAK | expect_fail 42501 | bundle SESI B | Confirmed |
| B11 | notifikasi milik A TIDAK terlihat oleh B | count=0 | bundle SESI B | Confirmed |
| B12 | activity feed terlihat oleh B | count>=1 | bundle SESI B | **BLOCKED** — feed following, B tidak follow A → perlu revisi |
| B13 | view rating menunjukkan review aktif | count=1, avg=4.0 | bundle SESI B | Confirmed |
| N04 | B TIDAK bisa menandai read notifikasi A | expect_0rows | revision Step 4 | Confirmed |

Sesi A KEMBALI (notifikasi) — 13 test (A13–A21 + N01–N03 + S01):

| ID | Tujuan | Expected | Source | Confidence |
|---|---|---|---|---|
| A13 | like/comment/follow B melahirkan 3 notifikasi untuk A | count=3 | bundle SESI A-kembali | Confirmed |
| A14 | pemilik boleh UPDATE notifikasi sendiri (tandai read) | expect_pass | bundle SESI A-kembali | Confirmed |
| A15 | notifikasi REVIEW_LIKED berstatus read | count=1 | bundle SESI A-kembali | Confirmed |
| A16 | soft-delete review sendiri diizinkan | expect_pass | bundle SESI A-kembali | Confirmed |
| A17 | review terhapus TIDAK terlihat di tabel | count=0 | bundle SESI A-kembali | Confirmed |
| A18 | view rating TIDAK menghitung review terhapus | count=0 | bundle SESI A-kembali | Confirmed |
| A19 | like pada review terhapus tidak terlihat | count=0 | bundle SESI A-kembali | Confirmed |
| A20 | visibility entry bisa diubah pemilik (PRIVATE -> PUBLIC) | expect_pass | bundle SESI A-kembali | Confirmed |
| A21 | profile_stats mengembalikan tepat 1 baris agregat | count=1 | bundle SESI A-kembali | Confirmed |
| N01 | notification_type notifikasi sendiri TIDAK bisa diubah | expect_fail 42501 | revision Step 5 | Confirmed |
| N02 | actor_id notifikasi sendiri TIDAK bisa diubah | expect_fail 42501 | revision Step 5 | Confirmed |
| N03 | user_id notifikasi sendiri TIDAK bisa diubah | expect_fail 42501 | revision Step 5 | Confirmed |
| S01 | stats publik TANPA koleksi privat (baca=1, sedang=0) | true | revision Step 6 | Confirmed |

**Sesi V (visibility) — 18 test (V01–V18):**

| ID | Tujuan | Expected | Source | Confidence |
|---|---|---|---|---|
| V01 | INSERT entri PRIVATE (vb1) diizinkan | expect_pass | revision Step 7 | Confirmed |
| V02 | entri PRIVATE TANPA aktivitas publik | count=0 | revision Step 7 | Confirmed |
| V03 | INSERT entri PUBLIC (vb2) diizinkan | expect_pass | revision Step 7 | Confirmed |
| V04 | entri PUBLIC membuat aktivitas (BOOK_ADDED) | count>=1 | revision Step 7 | Confirmed |
| V05 | UPDATE status vb1 saat PRIVATE diizinkan | expect_pass | revision Step 7 | Confirmed |
| V06 | status berubah saat PRIVATE tetap TANPA aktivitas | count=0 | revision Step 7 | Confirmed |
| V07 | vb1 PRIVATE -> PUBLIC saja diizinkan | expect_pass | revision Step 7 | Confirmed |
| V08 | transisi PRIVATE->PUBLIC TANPA aktivitas retroaktif | count=0 | revision Step 7 | Confirmed |
| V09 | UPDATE progress vb1 (kini PUBLIC) diizinkan | expect_pass | revision Step 7 | Confirmed |
| V10 | progress saat PUBLIC MEMBUAT aktivitas | count>=1 | revision Step 7 | Confirmed |
| V11 | A membuat review berkonten pada vb1 | expect_pass | revision Step 7 | Confirmed |
| V12 | aktivitas REVIEW_CREATED vb1 tercipta | count=1 | revision Step 7 | Confirmed |
| V13 | vb1 PUBLIC -> PRIVATE diizinkan | expect_pass | revision Step 7 | Confirmed |
| V14 | PUBLIC->PRIVATE MEMPURGE aktivitas library | count=0 | revision Step 7 | Confirmed |
| V15 | aktivitas REVIEW vb1 TIDAK ikut terhapus (purge bertipe) | count=1 | revision Step 7 | Confirmed |
| V16 | DELETE entri vb2 (PUBLIC) diizinkan | expect_pass | revision Step 7 | Confirmed |
| V17 | DELETE entri publik MEMPURGE aktivitas library-nya | count=0 | revision Step 7 | Confirmed |
| V18 | B TIDAK bisa mengubah visibility entri milik A | expect_0rows | revision Step 7 | Confirmed |

**Sesi ANON (tanpa login) — 8 test (AN01–AN08):**

| ID | Tujuan | Expected | Source | Confidence |
|---|---|---|---|---|
| AN01 | anon TIDAK bisa SELECT notes | expect_fail 42501 | revision Step 8 | Confirmed |
| AN02 | anon TIDAK bisa INSERT library_entries | expect_fail 42501 | revision Step 8 | Confirmed |
| AN03 | anon TIDAK bisa INSERT activities | expect_fail 42501 | revision Step 8 | Confirmed |
| AN04 | anon TIDAK bisa UPDATE notifications | expect_fail 42501 | revision Step 8 | Confirmed |
| AN05 | anon MASIH bisa membaca activity feed | count>=1 | revision Step 8 | **BLOCKED** — feed following, anon tidak follow siapa pun |
| AN06 | anon MASIH bisa membaca statistik profil publik | count>=1 | revision Step 8 | Confirmed |
| AN07 | anon melihat entri PUBLIC | count=1 | revision Step 8 | Confirmed |
| AN08 | anon TIDAK melihat entri PRIVATE | count=0 | revision Step 8 | Confirmed |

**Sesi POSTGRES (tanpa RLS) — 8 test (P01–P05 + K04 + P06 + P07):**

| ID | Tujuan | Expected | Source | Confidence |
|---|---|---|---|---|
| P01 | bio B tidak berubah (update A terefek 0 baris) | true | bundle POSTGRES | Confirmed |
| P02 | progress entry privat A masih 10 | true | bundle POSTGRES | Confirmed |
| P03 | notes A bertahan sebagai RAHASIA-BARU | true | bundle POSTGRES | Confirmed |
| P04 | review A ber-rating 4.0 | true | bundle POSTGRES | Confirmed |
| P05 | review A masih terakhir (soft-delete) | true | bundle POSTGRES | Confirmed |
| K04 | judul book1 utuh (UPDATE klien tadi tidak berefek) | true | revision Step 9 | Confirmed |
| P06 | stats: entri publik terhitung (baca=1, sedang=1); vb1 privat tidak | true | revision Step 9 | Confirmed |
| P07 | notif REVIEW_LIKED utuh (type & actor tidak berubah oleh N01/N02) | true | revision Step 9 | Confirmed |

**Total: 15 + 14 + 13 + 18 + 8 + 8 = 76 ✓** (39 lama + 37 baru).

### C-4. Assertion BLOCKED (2 buah)
| ID | Alasan | Perbaikan yang dibutuhkan |
|---|---|---|
| AN05 | `count(*) >= 1 from activities` sebagai anon. Dengan policy `activities_select_following` + grant `activities` HANYA ke authenticated, anon TIDAK punya akses → 42501, bukan `>=1`. | Pilih: (a) ganti expected → `expect_fail 42501` (anon benar-benar tidak boleh lihat feed following), ATAU (b) tambah `grant select on public.activities to anon` — **tidak direkomendasikan** (PRD: feed following, anon tanpa login tidak boleh lihat aktivitas siapa pun). Rekomendasi: (a). |
| B12 | `count(*) >= 1 from activities` sebagai B. B tidak follow A → 0 baris. | Ubah expected → `count(*) = 0` (B hanya melihat aktivitas yang diikuti; B tidak mengikuti A di fixture). |

**Kedua perubahan ini adalah perubahan test, bukan perubahan policy/produksi.** Setelah disetujui, rekonstruksi 006 sudah konsisten dengan keputusan FOLLOWING.

<!-- CHUNK5 -->D

## D. ROOT CAUSE VALIDATION (FASE 3)

### D-1. Kehilangan isi file 006 (PRIMARY)
- File truncasi 113 baris, mulai di tengah `set_config` SESI B. Tidak ada `begin;`, harness, fixture, SESI A/B/A-kembali/V. Hanya 17 `_t006_expect` (target 76).
- **"29 gagal/47 sukses" MUSTAHIL berasal dari file ini** (syntax error langsung). Hasil lama berasal dari versi lengkap yang tidak ada di repo.
- Tindakan: rekonstruksi 006 dari bundle lama + 37 test baru. Tidak ada perubahan migration.

### D-2. Ketidaksesuaian spesifikasi dengan PRD
- Rencana §1A-A: "feed tetap publik". PRD FR-08 (252), 272, 409: "Home feed hanya menampilkan aktivitas dari pengguna yang diikuti."
- → Spesifikasi yang kontradiksi. **Perbaiki spesifikasi, bukan policy.** Policy `activities_select_following` di 005 sudah benar.

### D-3. Potensi masalah konfigurasi/eksekusi RLS
- **auth.uid() NULL di RLS:** semua INSERT policies pakai `with check (user_id = (select auth.uid()))`. Jika NULL → 42501. Probe operator kemungkinan dijalankan sebagai postgres (bypass RLS) → tidak membuktikan evaluasi RLS.
- **Perbedaan grant:** `grant select on public.activities to authenticated` (005:66) TANPA anon; `grant select on table public.profile_stats to anon, authenticated` (004:392) ADA anon. Kedua view punya `security_invoker = on`.
- **Beda pernyataan sebelumnya:** `profile_stats` JUGA punya `security_invoker = on` (004:350) — koreksi.
- **Bedakan role:** uji dengan role `postgres` bypass RLS (tidak menguji RLS). Uji dengan role authenticated yang benar-benar melewati RLS. Rekonstruksi 006 menggunakan role switching (A/B/anon/postgres) — sudah benar.

## E. ANALISIS GRANT DAN RLS (FASE 3 lanjutan)
- **activities:** grant select HANYA ke authenticated (005:66). Tidak ada grant ke anon. Tidak ada policy `using (true)`.
- **notifications:** grant select 8 kolom + `update(read)` ke authenticated (005:68-79). Tidak ada grant ke anon.
- **profile_stats:** grant select ke anon + authenticated (004:392). security_invoker=on (004:350).
- **book_rating_summary:** grant select ke anon + authenticated (004:344). security_invoker=on (004:331).
- **library_entries:** grant select 10 kolom (tanpa notes) ke anon + authenticated; insert/update/delete ke authenticated (003:40-45).
- **reviews:** grant select ke anon + authenticated; insert/update ke authenticated (004:97-99).
- **likes/comments/follows:** grant select ke anon + authenticated; insert/delete ke authenticated (004:101-111).
- **books:** grant select ke anon + authenticated; insert ke authenticated (002:118-127).
- **profiles:** grant select ke anon + authenticated; update ke authenticated (002:118-120).

## F. RENCANA REKONSTRUKSI SCRIPT (FASE 4)

### F-1. Urutan implementasi
1. **Persetujuan pengguna** atas 2 BLOCKED (AN05, B12) — lihat C-4.
2. **Rekonstruksi `006_negative_tests.sql`** (617 baris) dari:
   - Fondasi: `db/AUDIT_REVIEW_BUNDLE.md` (harness + fixture + SESI A/B/A-kembali/POSTGRES/RINGKasAN).
   - 37 test baru: `execution-task-2-security-revision-plan.md` Step 3–9.
   - Tambah `v_book_v1 uuid; v_book_v2 uuid;` ke `declare` fixture (448).
   - Tambah 2 buku fixture (`t006-book-v1`, `t006-book-v2`) + 2 key (`book_v1`, `book_v2`) di `_t006_ids`.
3. **Verifikasi struktur:** `grep -c "^select public._t006_expect"` = 76; urutan sesi FIXTURE → SESI A → SESI B → SESI A KEMBALI → SESI V → SESI ANON → POSTGRES → RINGKASAN; nol duplikat ID; `begin;` + `rollback;`.
4. **Perbarui spesifikasi §1A-A** (feed following, bukan publik) — dokumen rencana saja, tanpa ubah migration.
5. **Eksekusi 006 di SQL Editor** (satu Run) → target `ALL NEGATIVE TESTS PASSED: 76 pemeriksaan`.
6. **Eksekusi 007** → `VERIFY SCHEMA: ALL 31 CHECKS PASSED`.

### F-2. Kriteria penerimaan Task 2
- Script 006 lengkap 76 assertion, sumbernya terverifikasi (bundle + revision plan).
- 76/76 PASS di SQL Editor (satu transaksi, rollback bersih, nol residu).
- 007: 31/31 CHECKS PASSED.
- Policy `activities` = `activities_select_following` (005 tidak diubah).
- Spesifikasi §1A-A diperbarui konsisten dengan PRD FR-08.
- 001–005 & 007 tidak diubah.
- SCHEMA_STATE diperbarui HANYA setelah Gate V2 LULUS.
- Tidak ada commit/push; Execution Task 3 belum dimulai.

## G. RISIKO YANG BELUM TERSELESAIKAN
| ID | Risiko | Dampak | Mitigasi |
|---|---|---|---|
| R-12 | Rekonstruksi 006 mengandung kesalahan (tanpa eksekusi) | 76/76 tidak tercapai | Verifikasi struktur (76 expects, urutan sesi, nol duplikat) sebelum Run; jangan klaim PASS tanpa eksekusi. |
| R-13 | `auth.uid()` NULL di RLS | 42501 pada kontrol positif INSERT | Uji dengan role authenticated yang benar-benar melewati RLS (role switching di 006 sudah dilakukan); jangan probe sebagai postgres. |
| R-14 | AN05/B12 gagal karena feed following | 2 test perlu revisi | Sudah diidentifikasi sebagai BLOCKED (C-4); butuh persetujuan. |
| R-15 | Grant `activities` ke anon tidak ditambahkan | AN05 (anon) tidak bisa baca feed | Tidak menambahkan grant — PRD: anon tanpa login tidak boleh lihat aktivitas. |
| R-16 | Spesifikasi §1A-A masih menyebut "publik" | Operator salah menindak | Perbarui spesifikasi di FASE 4 Step 4. |

## H. KEPUTUSAN YANG MASIH DIPERLUHKAN
1. **AN05:** ganti expected → `expect_fail 42501` (anon benar-benar tidak boleh lihat feed following) ATAU tambah `grant select on public.activities to anon` (tidak direkomendasikan).
2. **B12:** ubah expected → `count(*) = 0` (B tidak follow A).
3. **Perbarui spesifikasi §1A-A** sesuai keputusan FOLLOWING.
4. **Sumber rekonstruksi:** operator konfirmasi bahwa rekonstruksi dari bundle + revision plan sudah mencakupi semua 76 assertion.

## I. BATASAN
Tidak ubah 001–005, 007, PRD, ROADMAP, ADR, SCHEMA_STATE, bundle. Tidak kurangi assertion (76 tetap). Tidak commit/push. Tidak mulai Execution Task 3. Tidak ubah policy produksi.

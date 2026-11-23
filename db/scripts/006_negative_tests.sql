-- ============================================================================
-- 006_negative_tests.sql — seluruh negative authorization test.
-- Prasyarat: 2 akun uji sudah terdaftar di Supabase Dashboard (Authentication →
-- Users); dua profil pertama menurut join_date dipakai sebagai A dan B.
-- Jalankan setelah 005. Satu transaksi, diakhiri ROLLBACK → NOL RESIDU
-- (tabel uji, fungsi uji, fixture, dan seluruh perubahan data ikut terhapus).
-- Marker keberhasilan: 'ALL NEGATIVE TESTS PASSED: 76 pemeriksaan'
-- Sesi: A → B → A-kembali (notifikasi/statistik) → V (visibility) → ANON → POSTGRES.
-- ============================================================================

begin;

drop table if exists public._t006_results;
drop table if exists public._t006_ids;
drop function if exists public._t006_record(text, boolean, text);
drop function if exists public._t006_expect_true(text, text);
drop function if exists public._t006_expect_fail(text, text);
drop function if exists public._t006_expect_pass(text, text);
drop function if exists public._t006_expect_0rows(text, text);

create table public._t006_results (
  name   text primary key,
  ok     boolean not null,
  detail text
);
create table public._t006_ids (k text primary key, v uuid not null);

create or replace function public._t006_record(p_name text, p_ok boolean, p_detail text)
returns void language sql security definer set search_path = '' as $$
  insert into public._t006_results (name, ok, detail) values (p_name, p_ok, p_detail);
$$;

-- expect_true: SQL dinamis harus menghasilkan true (tanpa error)
create or replace function public._t006_expect_true(p_name text, p_sql text)
returns void language plpgsql as $$
declare v boolean;
begin
  execute p_sql into v;
  perform public._t006_record(p_name, coalesce(v, false),
    case when coalesce(v, false) then 'ok'
         else 'hasil: ' || coalesce(v::text, 'null') end);
exception when others then
  perform public._t006_record(p_name, false, sqlstate || ': ' || left(sqlerrm, 160));
end $$;
-- expect_fail: harus GAGAL dengan kode keamanan/konstraint yang benar
-- (42501 privilege/RLS, 23505 unique, 23514 check); error lain = FAIL
-- (mencegah lolos gara-gara typo/objek hilang).
create or replace function public._t006_expect_fail(p_name text, p_sql text)
returns void language plpgsql as $$
begin
  execute p_sql;
  perform public._t006_record(p_name, false, 'SEHARUSNYA gagal, tapi berhasil');
exception when others then
  perform public._t006_record(p_name, sqlstate in ('42501', '23505', '23514'),
    sqlstate || ': ' || left(sqlerrm, 140));
end $$;
-- expect_fail_42501: hanya gagal dengan sqlstate 42501 (privilege/RLS)
create or replace function public._t006_expect_fail_42501(p_name text, p_sql text)
returns void language plpgsql as $$
begin
  execute p_sql;
  perform public._t006_record(p_name, false, 'SEHARUSNYA gagal dengan 42501, tapi berhasil');
exception when others then
  perform public._t006_record(p_name, sqlstate = '42501',
    sqlstate || ': ' || left(sqlerrm, 140));
end $$;
create or replace function public._t006_expect_fail_23505(p_name text, p_sql text)
returns void language plpgsql as $$
begin
  execute p_sql;
  perform public._t006_record(p_name, false, 'SEHARUSNYA gagal dengan 23505, tapi berhasil');
exception when others then
  perform public._t006_record(p_name, sqlstate = '23505',
    sqlstate || ': ' || left(sqlerrm, 140));
end $$;
create or replace function public._t006_expect_fail_23514(p_name text, p_sql text)
returns void language plpgsql as $$
begin
  execute p_sql;
  perform public._t006_record(p_name, false, 'SEHARUSNYA gagal dengan 23514, tapi berhasil');
exception when others then
  perform public._t006_record(p_name, sqlstate = '23514',
    sqlstate || ': ' || left(sqlerrm, 140));
end $$;
-- expect_pass: DML/Statement harus SUKSES tanpa error (kontrol positif)
create or replace function public._t006_expect_pass(p_name text, p_sql text)
returns void language plpgsql as $$
begin
  execute p_sql;
  perform public._t006_record(p_name, true, 'ok');
exception when others then
  perform public._t006_record(p_name, false, sqlstate || ': ' || left(sqlerrm, 160));
end $$;
-- expect_0rows: DML yang mempengaruhi 0 baris (mode penolakan RLS khas UPDATE/DELETE)
create or replace function public._t006_expect_0rows(p_name text, p_sql text)
returns void language plpgsql as $$
declare n int;
begin
  execute p_sql;
  get diagnostics n = row_count;
  perform public._t006_record(p_name, n = 0, 'row_count=' || n);
exception when others then
  perform public._t006_record(p_name, sqlstate = '42501',
    'error ' || sqlstate || ': ' || left(sqlerrm, 140));
end $$;


-- ============================================================ FIXTURE (A/B) --
do $$
declare
  v_a uuid; v_b uuid; v_book1 uuid; v_book2 uuid;
  v_entry_priv uuid; v_entry_pub uuid; v_review uuid;
  v_book_v1 uuid; v_book_v2 uuid;
  n int;
begin
  select count(*) into n from public.profiles;
  if n < 2 then
    raise exception 'PRASYARAT GAGAL: butuh >= 2 profil. Buat 2 akun uji di Dashboard (Authentication -> Users) lalu jalankan ulang 006.';
  end if;
  select id into v_a from public.profiles order by join_date, id limit 1;
  select id into v_b from public.profiles order by join_date, id offset 1 limit 1;
  insert into public.books (google_books_id, title, authors, description)
  values ('t006-book-1', 'Buku Uji 006-1', array['Penulis Uji'], 'Fixture 006')
  returning id into v_book1;
  insert into public.books (google_books_id, title, authors, description)
  values ('t006-book-2', 'Buku Uji 006-2', array['Penulis Uji'], 'Fixture 006')
  returning id into v_book2;
  insert into public.books (google_books_id, title, authors, description)
  values ('t006-book-v1', 'Buku Uji V1', array['Penulis Uji'], 'Fixture 006')
  returning id into v_book_v1;
  insert into public.books (google_books_id, title, authors, description)
  values ('t006-book-v2', 'Buku Uji V2', array['Penulis Uji'], 'Fixture 006')
  returning id into v_book_v2;
  insert into public.library_entries (user_id, book_id, status, progress, visibility, notes)
  values (v_a, v_book1, 'READING', 10, 'PRIVATE', 'RAHASIA-A')
  returning id into v_entry_priv;
  insert into public.library_entries (user_id, book_id, status, progress, visibility, notes)
  values (v_a, v_book2, 'FINISHED', 100, 'PUBLIC', 'RAHASIA-PUB')
  returning id into v_entry_pub;
  insert into public.reviews (user_id, book_id, rating, title, content)
  values (v_a, v_book1, 4.0, 'Judul Uji', 'Isi ulasan uji untuk skrip 006.')
  returning id into v_review;
  insert into public._t006_ids (k, v) values
    ('a', v_a), ('b', v_b), ('book1', v_book1), ('book2', v_book2),
    ('entry_priv', v_entry_priv), ('entry_pub', v_entry_pub), ('review', v_review),
    ('book_v1', v_book_v1), ('book_v2', v_book_v2);
end $$;
-- ====================================================== SESI A (pemilik data) --
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub": "' || (select v from public._t006_ids where k = 'a') || '", "role": "authenticated"}',
  true);
select public._t006_expect_true('A01 notes terbaca via fungsi milik sendiri', $sql$
  select public.library_entry_notes((select v from public._t006_ids where k = 'entry_priv')) = 'RAHASIA-A'
$sql$);
select public._t006_expect_fail_42501('A02 notes TIDAK terbaca via SELECT tabel (hak kolom)', $sql$
  select notes from public.library_entries
  where id = (select v from public._t006_ids where k = 'entry_priv')
$sql$);
select public._t006_expect_true('A03 entry privat sendiri terlihat', $sql$
  select count(*) = 1 from public.library_entries
  where id = (select v from public._t006_ids where k = 'entry_priv')
$sql$);
select public._t006_expect_pass('A04 pemilik boleh UPDATE notes sendiri', $sql$
  update public.library_entries set notes = 'RAHASIA-BARU'
  where id = (select v from public._t006_ids where k = 'entry_priv')
$sql$);
select public._t006_expect_true('A05 notes hasil UPDATE terbaca via fungsi', $sql$
  select public.library_entry_notes((select v from public._t006_ids where k = 'entry_priv')) = 'RAHASIA-BARU'
$sql$);
select public._t006_expect_fail_42501('A06 INSERT activities langsung DITOLAK (tanpa policy)', $sql$
  insert into public.activities (actor_id, activity_type)
  values ((select v from public._t006_ids where k = 'a'), 'BOOK_ADDED')
$sql$);
select public._t006_expect_fail_42501('A07 INSERT notifications langsung DITOLAK (tanpa policy)', $sql$
  insert into public.notifications (user_id, notification_type)
  values ((select v from public._t006_ids where k = 'a'), 'NEW_FOLLOWER')
$sql$);
select public._t006_expect_0rows('A08 UPDATE profil orang lain TIDAK berpengaruh', $sql$
  update public.profiles set bio = 'HACKED-BY-A'
  where id = (select v from public._t006_ids where k = 'b')
$sql$);
select public._t006_expect_fail_23514('A09 rating di luar interval CHECK ditolak (4.3)', $sql$
  insert into public.reviews (user_id, book_id, rating)
  values ((select v from public._t006_ids where k = 'a'),
          (select v from public._t006_ids where k = 'book2'), 4.3)
$sql$);
select public._t006_expect_pass('A10 kontrol positif: insert review valid di buku lain', $sql$
  insert into public.reviews (user_id, book_id, rating)
  values ((select v from public._t006_ids where k = 'a'),
          (select v from public._t006_ids where k = 'book2'), 3.0)
$sql$);
select public._t006_expect_fail_23505('A11 review ganda pada buku sama DITOLAK (unique aktif)', $sql$
  insert into public.reviews (user_id, book_id, rating)
  values ((select v from public._t006_ids where k = 'a'),
          (select v from public._t006_ids where k = 'book1'), 5.0)
$sql$);
select public._t006_expect_fail_23514('A12 follow diri sendiri DITOLAK (constraint no-self)', $sql$
  insert into public.follows (follower_id, following_id)
  values ((select v from public._t006_ids where k = 'a'),
          (select v from public._t006_ids where k = 'a'))
$sql$);
select public._t006_expect_fail_42501('K01 UPDATE books oleh authenticated DITOLAK (insert-only)', $sql$
  update public.books set title = 'HACKED-TITLE'
  where id = (select v from public._t006_ids where k = 'book1')
$sql$);
select public._t006_expect_pass('K02 kontrol positif: INSERT buku baru oleh authenticated', $sql$
  insert into public.books (google_books_id, title, authors)
  values ('t006-book-3', 'Buku Uji K02', array['Penulis Uji'])
$sql$);
select public._t006_expect_pass('K03 jalur upsert klien: ON CONFLICT DO NOTHING tanpa hak UPDATE', $sql$
  insert into public.books (google_books_id, title, authors)
  values ('t006-book-1', 'Duplikat', array['X'])
  on conflict (google_books_id) do nothing
$sql$);
-- ====================================================== SESI B (pihak lain) --
reset role;
reset request.jwt.claims;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub": "' || (select v from public._t006_ids where k = 'b') || '", "role": "authenticated"}',
  true);
select public._t006_expect_fail_42501('B01 notes milik A TIDAK terbaca via SELECT tabel', $sql$
  select notes from public.library_entries
  where id = (select v from public._t006_ids where k = 'entry_priv')
$sql$);
select public._t006_expect_true('B02 entry PRIVATE milik A TIDAK terlihat', $sql$
  select count(*) = 0 from public.library_entries
  where id = (select v from public._t006_ids where k = 'entry_priv')
$sql$);
select public._t006_expect_true('B03 entry PUBLIC milik A terlihat', $sql$
  select count(*) = 1 from public.library_entries
  where id = (select v from public._t006_ids where k = 'entry_pub')
$sql$);
select public._t006_expect_0rows('B04 UPDATE entry PRIVATE milik A TIDAK berpengaruh', $sql$
  update public.library_entries set progress = 99
  where id = (select v from public._t006_ids where k = 'entry_priv')
$sql$);
select public._t006_expect_0rows('B05 UPDATE review milik A TIDAK berpengaruh', $sql$
  update public.reviews set rating = 1.0
  where id = (select v from public._t006_ids where k = 'review')
$sql$);
select public._t006_expect_0rows('B06 DELETE review milik A TIDAK berpengaruh (tanpa policy)', $sql$
  delete from public.reviews
  where id = (select v from public._t006_ids where k = 'review')
$sql$);
select public._t006_expect_pass('B07 kontrol positif: like review aktif A oleh B', $sql$
  insert into public.likes (review_id, user_id)
  values ((select v from public._t006_ids where k = 'review'),
          (select v from public._t006_ids where k = 'b'))
$sql$);
select public._t006_expect_pass('B08 kontrol positif: comment review aktif A oleh B', $sql$
  insert into public.comments (review_id, user_id, content)
  values ((select v from public._t006_ids where k = 'review'),
          (select v from public._t006_ids where k = 'b'), 'Komentar uji 006')
$sql$);
select public._t006_expect_pass('B09 kontrol positif: follow A oleh B', $sql$
  insert into public.follows (follower_id, following_id)
  values ((select v from public._t006_ids where k = 'b'),
          (select v from public._t006_ids where k = 'a'))
$sql$);
select public._t006_expect_fail_42501('B10 INSERT notifications langsung DITOLAK (tanpa policy)', $sql$
  insert into public.notifications (user_id, notification_type)
  values ((select v from public._t006_ids where k = 'b'), 'NEW_FOLLOWER')
$sql$);
select public._t006_expect_true('B11 notifikasi milik A TIDAK terlihat oleh B', $sql$
  select count(*) = 0 from public.notifications
  where user_id = (select v from public._t006_ids where k = 'a')
$sql$);
select public._t006_expect_true('B12 activity feed TIDAK terlihat oleh B', $sql$
  select count(*) = 0 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book1')
    and activity_type in ('BOOK_ADDED','BOOK_STARTED','BOOK_FINISHED','READING_PROGRESS_UPDATED')
$sql$);
select public._t006_expect_true('B13 view rating menunjukkan review aktif (count=1, avg=4.0)', $sql$
  select rating_count = 1 and avg_rating = 4.0 from public.book_rating_summary
  where book_id = (select v from public._t006_ids where k = 'book1')
$sql$);
select public._t006_expect_0rows('N04 B TIDAK bisa menandai read notifikasi A (RLS own)', $sql$
  update public.notifications set read = true
  where id = (
    select id from public.notifications
    where user_id = (select v from public._t006_ids where k = 'a')
      and notification_type = 'REVIEW_LIKED'
    limit 1
  )
$sql$);
-- =============================================== SESI A KEMBALI (notifikasi) --
reset role;
reset request.jwt.claims;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub": "' || (select v from public._t006_ids where k = 'a') || '", "role": "authenticated"}',
  true);
select public._t006_expect_true('A13 like/comment/follow B melahirkan 3 notifikasi untuk A (trigger)', $sql$
  select count(*) = 3 from public.notifications
  where user_id = (select v from public._t006_ids where k = 'a')
    and notification_type in ('REVIEW_LIKED', 'REVIEW_COMMENTED', 'NEW_FOLLOWER')
$sql$);
select public._t006_expect_pass('A14 pemilik boleh UPDATE notifikasi sendiri (tandai read)', $sql$
  update public.notifications set read = true
  where user_id = (select v from public._t006_ids where k = 'a')
    and notification_type = 'REVIEW_LIKED'
$sql$);
select public._t006_expect_true('A15 notifikasi REVIEW_LIKED berstatus read', $sql$
  select count(*) = 1 from public.notifications
  where user_id = (select v from public._t006_ids where k = 'a')
    and notification_type = 'REVIEW_LIKED' and read = true
$sql$);
select public._t006_expect_pass('A16 soft-delete review sendiri diizinkan', $sql$
  update public.reviews set deleted_at = now()
  where id = (select v from public._t006_ids where k = 'review')
$sql$);
select public._t006_expect_true('A17 review terhapus TIDAK terlihat di tabel (soft delete)', $sql$
  select count(*) = 0 from public.reviews
  where id = (select v from public._t006_ids where k = 'review')
$sql$);
select public._t006_expect_true('A18 view rating TIDAK menghitung review terhapus (count=0)', $sql$
  select rating_count = 0 from public.book_rating_summary
  where book_id = (select v from public._t006_ids where k = 'book1')
$sql$);
select public._t006_expect_true('A19 like pada review terhapus tidak terlihat', $sql$
  select count(*) = 0 from public.likes
  where review_id = (select v from public._t006_ids where k = 'review')
$sql$);
select public._t006_expect_pass('A20 visibility entry bisa diubah pemilik (PRIVATE -> PUBLIC)', $sql$
  update public.library_entries set visibility = 'PUBLIC'
  where id = (select v from public._t006_ids where k = 'entry_priv')
$sql$);
select public._t006_expect_true('A21 profile_stats mengembalikan tepat 1 baris agregat', $sql$
  select count(*) = 1 from public.profile_stats
  where profile_id = (select v from public._t006_ids where k = 'a')
$sql$);
select public._t006_expect_fail_42501('N01 notification_type notifikasi sendiri TIDAK bisa diubah', $sql$
  update public.notifications set notification_type = 'NEW_FOLLOWER'
  where id = (select id from public.notifications
              where user_id = (select v from public._t006_ids where k = 'a')
                and notification_type = 'REVIEW_LIKED' limit 1)
$sql$);
select public._t006_expect_fail_42501('N02 actor_id notifikasi sendiri TIDAK bisa diubah', $sql$
  update public.notifications set actor_id = (select v from public._t006_ids where k = 'a')
  where id = (select id from public.notifications
              where user_id = (select v from public._t006_ids where k = 'a'))
                and notification_type = 'REVIEW_LIKED' limit 1)
$sql$);
select public._t006_expect_fail_42501('N03 user_id notifikasi sendiri TIDAK bisa diubah', $sql$
  update public.notifications set user_id = (select v from public._t006_ids where k = 'b')
  where id = (select id from public.notifications
              where user_id = (select v from public._t006_ids where k = 'a'))
                and notification_type = 'REVIEW_LIKED' limit 1)
$sql$);
select public._t006_expect_true('S01 stats publik TANPA koleksi privat (baca=1, sedang=0)', $sql$
  select books_read = 1 and currently_reading = 0 from public.profile_stats
  where profile_id = (select v from public._t006_ids where k = 'a')
$sql$);
-- ===================================================== SESI V (visibility) --
reset role;
reset request.jwt.claims;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub": "' || (select v from public._t006_ids where k = 'a') || '", "role": "authenticated"}',
  true);
select public._t006_expect_pass('V01 INSERT entri PRIVATE (vb1) diizinkan', $sql$
  insert into public.library_entries (user_id, book_id, visibility)
  values ((select v from public._t006_ids where k = 'a'),
          (select v from public._t006_ids where k = 'book_v1'), 'PRIVATE')
$sql$);
select public._t006_expect_true('V02 entri PRIVATE TANPA aktivitas publik', $sql$
  select count(*) = 0 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
    and activity_type in ('BOOK_ADDED','BOOK_STARTED','BOOK_FINISHED','READING_PROGRESS_UPDATED')
$sql$);
select public._t006_expect_pass('V03 INSERT entri PUBLIC (vb2) diizinkan', $sql$
  insert into public.library_entries (user_id, book_id, visibility)
  values ((select v from public._t006_ids where k = 'a'),
          (select v from public._t006_ids where k = 'book_v2'), 'PUBLIC')
$sql$);
select public._t006_expect_true('V04 entri PUBLIC membuat aktivitas (BOOK_ADDED)', $sql$
  select count(*) >= 1 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v2')
    and activity_type in ('BOOK_ADDED','BOOK_STARTED','BOOK_FINISHED','READING_PROGRESS_UPDATED')
$sql$);
select public._t006_expect_pass('V05 UPDATE status vb1 saat PRIVATE diizinkan (tanpa aktivitas)', $sql$
  update public.library_entries set status = 'READING'
  where user_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
$sql$);
select public._t006_expect_true('V06 status berubah saat PRIVATE tetap TANPA aktivitas', $sql$
  select count(*) = 0 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
    and activity_type in ('BOOK_ADDED','BOOK_STARTED','BOOK_FINISHED','READING_PROGRESS_UPDATED')
$sql$);
select public._t006_expect_pass('V07 vb1 PRIVATE -> PUBLIC saja diizinkan', $sql$
  update public.library_entries set visibility = 'PUBLIC'
  where user_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
$sql$);
select public._t006_expect_true('V08 transisi PRIVATE->PUBLIC TANPA aktivitas retroaktif', $sql$
  select count(*) = 0 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
    and activity_type in ('BOOK_ADDED','BOOK_STARTED','BOOK_FINISHED','READING_PROGRESS_UPDATED')
$sql$);
select public._t006_expect_pass('V09 UPDATE progress vb1 (kini PUBLIC) diizinkan', $sql$
  update public.library_entries set progress = 40
  where user_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
$sql$);
select public._t006_expect_true('V10 progress saat PUBLIC MEMBUAT aktivitas', $sql$
  select count(*) >= 1 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
    and activity_type in ('BOOK_ADDED','BOOK_STARTED','BOOK_FINISHED','READING_PROGRESS_UPDATED')
$sql$);
select public._t006_expect_pass('V11 A membuat review berkonten pada vb1', $sql$
  insert into public.reviews (user_id, book_id, rating, content)
  values ((select v from public._t006_ids where k = 'a'),
          (select v from public._t006_ids where k = 'book_v1'), 4.5, 'Konten uji visibility')
$sql$);
select public._t006_expect_true('V12 aktivitas REVIEW_CREATED vb1 tercipta', $sql$
  select count(*) = 1 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
    and activity_type = 'REVIEW_CREATED'
$sql$);
select public._t006_expect_pass('V13 vb1 PUBLIC -> PRIVATE diizinkan', $sql$
  update public.library_entries set visibility = 'PRIVATE'
  where user_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
$sql$);
select public._t006_expect_true('V14 PUBLIC->PRIVATE MEMPURGE aktivitas library (bocor dicegah)', $sql$
  select count(*) = 0 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
    and activity_type in ('BOOK_ADDED','BOOK_STARTED','BOOK_FINISHED','READING_PROGRESS_UPDATED')
$sql$);
select public._t006_expect_true('V15 aktivitas REVIEW vb1 TIDAK ikut terhapus (purge bertipe)', $sql$
  select count(*) = 1 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
    and activity_type = 'REVIEW_CREATED'
$sql$);
select public._t006_expect_pass('V16 DELETE entri vb2 (PUBLIC) diizinkan', $sql$
  delete from public.library_entries
  where user_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v2')
$sql$);
select public._t006_expect_true('V17 DELETE entri publik MEMPURGE aktivitas library-nya', $sql$
  select count(*) = 0 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v2')
    and activity_type in ('BOOK_ADDED','BOOK_STARTED','BOOK_FINISHED','READING_PROGRESS_UPDATED')
$sql$);
reset role;
reset request.jwt.claims;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub": "' || (select v from public._t006_ids where k = 'b') || '", "role": "authenticated"}',
  true);
reset role;
reset request.jwt.claims;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub": "' || (select v from public._t006_ids where k = 'b') || '", "role": "authenticated"}',
  true);
select public._t006_expect_0rows('V18 B TIDAK bisa mengubah visibility entri milik A', $sql$
  update public.library_entries set visibility = 'PRIVATE'
  where user_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
$sql$);
-- ==================================================== SESI ANON (tanpa login) --
reset role;
reset request.jwt.claims;
set local role anon;
select public._t006_expect_fail_42501('AN01 anon TIDAK bisa SELECT notes', $sql$
  select notes from public.library_entries
  where id = (select v from public._t006_ids where k = 'entry_priv')
$sql$);
select public._t006_expect_fail_42501('AN02 anon TIDAK bisa INSERT library_entries', $sql$
  insert into public.library_entries (user_id, book_id, visibility)
  values ((select v from public._t006_ids where k = 'a'),
          (select v from public._t006_ids where k = 'book1'), 'PUBLIC')
$sql$);
select public._t006_expect_fail_42501('AN03 anon TIDAK bisa INSERT activities', $sql$
  insert into public.activities (actor_id, activity_type)
  values ((select v from public._t006_ids where k = 'a'), 'BOOK_ADDED')
$sql$);
select public._t006_expect_fail_42501('AN04 anon TIDAK bisa UPDATE notifications', $sql$
  update public.notifications set read = true
  where user_id = (select v from public._t006_ids where k = 'a')
$sql$);
select public._t006_expect_fail_42501('AN05 anon TIDAK bisa membaca activity feed publik', $sql$
  select count(*) >= 1 from public.activities
$sql$);
select public._t006_expect_true('AN06 anon MASIH bisa membaca statistik profil publik', $sql$
  select count(*) >= 1 from public.profile_stats
$sql$);
select public._t006_expect_true('AN07 anon melihat entri PUBLIC', $sql$
  select count(*) = 1 from public.library_entries
  where id = (select v from public._t006_ids where k = 'entry_pub')
$sql$);
select public._t006_expect_true('AN08 anon TIDAK melihat entri PRIVATE milik A', $sql$
  select count(*) = 0 from public.library_entries
  where book_id = (select v from public._t006_ids where k = 'book_v1')
    and user_id = (select v from public._t006_ids where k = 'a')
$sql$);
-- ===================================================== POSTGRES (tanpa RLS) --
reset role;
reset request.jwt.claims;
select public._t006_expect_true('P01 bio B tidak berubah (update A terefek 0 baris)', $sql$
  select bio is distinct from 'HACKED-BY-A' from public.profiles
  where id = (select v from public._t006_ids where k = 'b')
$sql$);
select public._t006_expect_true('P02 progress entry privat A masih 10 (update B terefek 0 baris)', $sql$
  select progress = 10 from public.library_entries
  where id = (select v from public._t006_ids where k = 'entry_priv')
$sql$);
select public._t006_expect_true('P03 notes A bertahan sebagai RAHASIA-BARU (tulis via tabel ok)', $sql$
  select notes = 'RAHASIA-BARU' from public.library_entries
  where id = (select v from public._t006_ids where k = 'entry_priv')
$sql$);
select public._t006_expect_true('P04 review A ber-rating 4.0 (update B terefek 0 baris)', $sql$
  select rating = 4.0 from public.reviews
  where id = (select v from public._t006_ids where k = 'review')
$sql$);
select public._t006_expect_true('P05 review A ber-status aktif kembali? TIDAK — masih terhapus', $sql$
  select deleted_at is not null from public.reviews
  where id = (select v from public._t006_ids where k = 'review')
$sql$);
select public._t006_expect_true('K04 judul book1 utuh (UPDATE klien tadi tidak berefek)', $sql$
  select title = 'Buku Uji 006-1' from public.books
  where id = (select v from public._t006_ids where k = 'book1')
$sql$);
select public._t006_expect_true('P06 stats: entri publik terhitung (baca=1, sedang=1); vb1 privat tidak', $sql$
  select books_read = 1 and currently_reading = 1 from public.profile_stats
  where profile_id = (select v from public._t006_ids where k = 'a')
$sql$);
select public._t006_expect_true('P07 notif REVIEW_LIKED utuh (type & actor tidak berubah oleh N01/N02)', $sql$
  select notification_type = 'REVIEW_LIKED'
     and actor_id = (select v from public._t006_ids where k = 'b')
  from public.notifications
  where user_id = (select v from public._t006_ids where k = 'a')
    and notification_type = 'REVIEW_LIKED'
  limit 1
$sql$);
-- ================================================================ RINGKASAN --

grant select on public._t006_results to authenticated;
grant select on public._t006_ids to authenticated;

select name, ok, detail from public._t006_results where not ok order by name;
select
case
when count(*) = count(*) filter (where ok)
then 'ALL NEGATIVE TESTS PASSED: ' || count(*) || ' pemeriksaan'
else 'TESTS FAILED: ' || count(*) filter (where not ok) || ' gagal dari '
|| count(*) || ' pemeriksaan'
end as hasil
from public._t006_results;
rollback;



-- ============================================================================
-- 004_reviews_social.sql — reviews (soft delete), likes, comments, follows,
-- view book_rating_summary (hanya review aktif), view profile_stats (agregat
-- publik tanpa detail library privat), + RLS.
-- Jalankan setelah 003.
-- ============================================================================

-- ---------------------------------------------------------------- reviews --
create table if not exists public.reviews (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  book_id    uuid not null references public.books (id) on delete cascade,
  rating     numeric(2,1) not null,
  title      text,
  content    text,
  spoiler    boolean not null default false,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reviews_rating_range check (rating >= 0.5 and rating <= 5.0),
  constraint reviews_rating_interval check (round(rating * 2) = rating * 2),
  constraint reviews_title_len check (title is null or char_length(title) <= 300),
  constraint reviews_content_len check (content is null or char_length(content) <= 10000)
);

-- 1 review aktif per user per book.
create unique index if not exists reviews_one_active_per_book
  on public.reviews (user_id, book_id) where deleted_at is null;

create index if not exists reviews_book_active_idx
  on public.reviews (book_id) where deleted_at is null;

create index if not exists reviews_user_id_idx
  on public.reviews (user_id);

do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'reviews_set_updated_at'
      and tgrelid = 'public.reviews'::regclass
  ) then
    create trigger reviews_set_updated_at
      before update on public.reviews
      for each row execute function public.set_updated_at();
  end if;
end $$;

-- ------------------------------------------------------------------ likes --
create table if not exists public.likes (
  review_id uuid not null references public.reviews (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (review_id, user_id)
);

create index if not exists likes_user_id_idx
  on public.likes (user_id);

-- --------------------------------------------------------------- comments --
create table if not exists public.comments (
  id         uuid primary key default gen_random_uuid(),
  review_id  uuid not null references public.reviews (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  content    text not null,
  created_at timestamptz not null default now(),
  constraint comments_content_len check (char_length(content) between 1 and 5000)
);

create index if not exists comments_review_id_idx
  on public.comments (review_id);

create index if not exists comments_user_id_idx
  on public.comments (user_id);

-- ---------------------------------------------------------------- follows --
create table if not exists public.follows (
  follower_id  uuid not null references public.profiles (id) on delete cascade,
  following_id uuid not null references public.profiles (id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint follows_no_self check (follower_id <> following_id)
);

create index if not exists follows_following_idx
  on public.follows (following_id);

-- -------------------------------------------------------------------- RLS --
alter table public.reviews enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.follows enable row level security;

-- Grant eksplisit: revoke lalu grant minimal.
revoke all on table public.reviews from anon, authenticated;
grant select on table public.reviews to anon, authenticated;
grant insert, update on table public.reviews to authenticated;

revoke all on table public.likes from anon, authenticated;
grant select on table public.likes to anon, authenticated;
grant insert, delete on table public.likes to authenticated;

revoke all on table public.comments from anon, authenticated;
grant select on table public.comments to anon, authenticated;
grant insert, delete on table public.comments to authenticated;

revoke all on table public.follows from anon, authenticated;
grant select on table public.follows to anon, authenticated;
grant insert, delete on table public.follows to authenticated;

-- ---------------------------------------------------------------- policies --
do $$
begin
  -- REVIEWS
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'reviews'
      and policyname = 'reviews_select_active'
  ) then
    execute $p$
      create policy "reviews_select_active"
      on public.reviews
      for select
      using (deleted_at is null)
    $p$;
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'reviews'
      and policyname = 'reviews_insert_own'
  ) then
    execute $p$
      create policy "reviews_insert_own"
      on public.reviews
      for insert
      with check (user_id = (select auth.uid()))
    $p$;
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'reviews'
      and policyname = 'reviews_update_own'
  ) then
    execute $p$
      create policy "reviews_update_own"
      on public.reviews
      for update
      using (
        user_id = (select auth.uid())
        and deleted_at is null
      )
      with check (user_id = (select auth.uid()))
    $p$;
  end if;

  -- LIKES
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'likes'
      and policyname = 'likes_select_active_review'
  ) then
    execute $p$
      create policy "likes_select_active_review"
      on public.likes
      for select
      using (
        exists (
          select 1
          from public.reviews r
          where r.id = likes.review_id
            and r.deleted_at is null
        )
      )
    $p$;
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'likes'
      and policyname = 'likes_insert_own_active_review'
  ) then
    execute $p$
      create policy "likes_insert_own_active_review"
      on public.likes
      for insert
      with check (
        user_id = (select auth.uid())
        and exists (
          select 1
          from public.reviews r
          where r.id = likes.review_id
            and r.deleted_at is null
        )
      )
    $p$;
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'likes'
      and policyname = 'likes_delete_own'
  ) then
    execute $p$
      create policy "likes_delete_own"
      on public.likes
      for delete
      using (user_id = (select auth.uid()))
    $p$;
  end if;

  -- COMMENTS
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'comments'
      and policyname = 'comments_select_active_review'
  ) then
    execute $p$
      create policy "comments_select_active_review"
      on public.comments
      for select
      using (
        exists (
          select 1
          from public.reviews r
          where r.id = comments.review_id
            and r.deleted_at is null
        )
      )
    $p$;
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'comments'
      and policyname = 'comments_insert_own_active_review'
  ) then
    execute $p$
      create policy "comments_insert_own_active_review"
      on public.comments
      for insert
      with check (
        user_id = (select auth.uid())
        and exists (
          select 1
          from public.reviews r
          where r.id = comments.review_id
            and r.deleted_at is null
        )
      )
    $p$;
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'comments'
      and policyname = 'comments_delete_own'
  ) then
    execute $p$
      create policy "comments_delete_own"
      on public.comments
      for delete
      using (user_id = (select auth.uid()))
    $p$;
  end if;

  -- FOLLOWS
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'follows'
      and policyname = 'follows_select_public'
  ) then
    execute $p$
      create policy "follows_select_public"
      on public.follows
      for select
      using (true)
    $p$;
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'follows'
      and policyname = 'follows_insert_own'
  ) then
    execute $p$
      create policy "follows_insert_own"
      on public.follows
      for insert
      with check (
        follower_id = (select auth.uid())
        and follower_id <> following_id
      )
    $p$;
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'follows'
      and policyname = 'follows_delete_own'
  ) then
    execute $p$
      create policy "follows_delete_own"
      on public.follows
      for delete
      using (follower_id = (select auth.uid()))
    $p$;
  end if;
end $$;

-- ---------------------------------------------------------------- views ----

-- Agregat rating hanya dari review aktif.
-- security_invoker memastikan view mengikuti RLS caller.
create or replace view public.book_rating_summary
with (security_invoker = on) as
select
  b.id as book_id,
  count(r.id)::bigint as rating_count,
  coalesce(avg(r.rating), 0)::numeric(3, 2) as avg_rating
from public.books b
left join public.reviews r
  on r.book_id = b.id
  and r.deleted_at is null
group by b.id;

-- PostgreSQL menggunakan ON TABLE untuk GRANT/REVOKE pada view.
revoke all on table public.book_rating_summary from anon, authenticated;
grant select on table public.book_rating_summary to anon, authenticated;

-- Statistik profil publik hanya berupa angka agregat.
-- Entri library PRIVATE tidak ikut dihitung.
-- security_invoker memastikan akses mengikuti RLS caller.
create or replace view public.profile_stats
with (security_invoker = on) as
select
  p.id as profile_id,

  (
    select count(*)
    from public.library_entries l
    where l.user_id = p.id
      and l.visibility = 'PUBLIC'
      and l.status = 'FINISHED'
  )::bigint as books_read,

  (
    select count(*)
    from public.library_entries l
    where l.user_id = p.id
      and l.visibility = 'PUBLIC'
      and l.status = 'READING'
  )::bigint as currently_reading,

  (
    select count(*)
    from public.reviews r
    where r.user_id = p.id
      and r.deleted_at is null
  )::bigint as reviews_count,

  (
    select count(*)
    from public.follows f
    where f.following_id = p.id
  )::bigint as followers_count,

  (
    select count(*)
    from public.follows f
    where f.follower_id = p.id
  )::bigint as following_count

from public.profiles p;

revoke all on table public.profile_stats from anon, authenticated;
grant select on table public.profile_stats to anon, authenticated;

-- ---------------------------------------------------------------- VERIFY --

-- 1. RLS: harus menghasilkan 4 baris dengan relrowsecurity = true.
select
  c.relname as table_name,
  c.relrowsecurity
from pg_class c
where c.oid in (
  'public.reviews'::regclass,
  'public.likes'::regclass,
  'public.comments'::regclass,
  'public.follows'::regclass
)
order by c.relname;

-- 2. Policies.
select
  tablename,
  policyname,
  cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('reviews', 'likes', 'comments', 'follows')
order by tablename, policyname;

-- Harapan:
-- reviews TANPA policy DELETE.
-- comments TANPA policy UPDATE.

-- 3. Views: harus menghasilkan 2 baris.
select viewname
from pg_views
where schemaname = 'public'
  and viewname in ('book_rating_summary', 'profile_stats')
order by viewname;

-- 4. Index reviews.
select indexname
from pg_indexes
where schemaname = 'public'
  and tablename = 'reviews'
order by indexname;

-- Harapan:
-- reviews_book_active_idx
-- reviews_one_active_per_book
-- reviews_user_id_idx
-- reviews_pkey

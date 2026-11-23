
-- ============================================================================
-- 005_activity_notifications.sql — activities + notifications + trigger.
--
-- Keputusan:
-- 1. Activities dan notifications hanya dibuat melalui database trigger.
-- 2. Client tidak memiliki policy INSERT untuk kedua tabel.
-- 3. Activity feed hanya dapat dibaca oleh pengguna login:
--    - aktivitas milik sendiri;
--    - aktivitas akun yang diikuti.
-- 4. Aktivitas library hanya dibuat untuk entri PUBLIC.
-- 5. Notes pribadi tidak disalin ke activities.
--
-- Jalankan setelah 004_reviews_social.sql.
-- ============================================================================


-- ============================================================ TABLES =======

create table if not exists public.activities (
  id              uuid primary key default gen_random_uuid(),
  actor_id        uuid not null references public.profiles (id) on delete cascade,
  target_user_id  uuid references public.profiles (id) on delete cascade,
  book_id         uuid references public.books (id) on delete cascade,
  review_id       uuid references public.reviews (id) on delete cascade,
  activity_type   public.activity_type not null,
  created_at      timestamptz not null default now()
);

create index if not exists activities_created_at_idx
  on public.activities (created_at desc);

create index if not exists activities_target_user_idx
  on public.activities (target_user_id);

create index if not exists activities_actor_idx
  on public.activities (actor_id);

create index if not exists activities_actor_book_idx
  on public.activities (actor_id, book_id);


create table if not exists public.notifications (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.profiles (id) on delete cascade,
  notification_type public.notification_type not null,
  actor_id          uuid references public.profiles (id) on delete cascade,
  review_id         uuid references public.reviews (id) on delete cascade,
  comment_id        uuid references public.comments (id) on delete cascade,
  read              boolean not null default false,
  created_at        timestamptz not null default now()
);

create index if not exists notifications_user_created_idx
  on public.notifications (user_id, created_at desc);


-- ================================================================ GRANTS ===

alter table public.activities enable row level security;
alter table public.notifications enable row level security;

revoke all on public.activities from anon, authenticated;
revoke all on public.notifications from anon, authenticated;

grant select on public.activities to authenticated;

grant select (
  id,
  user_id,
  notification_type,
  actor_id,
  review_id,
  comment_id,
  read,
  created_at
) on public.notifications to authenticated;

grant update (read) on public.notifications to authenticated;


-- ================================================================ POLICIES =

do $$
begin
  -- Activities: own activity OR activity from followed accounts.
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'activities'
      and policyname = 'activities_select_following'
  ) then
    execute $policy$
      create policy "activities_select_following"
      on public.activities
      for select
      to authenticated
      using (
        actor_id = (select auth.uid())
        or exists (
          select 1
          from public.follows f
          where f.follower_id = (select auth.uid())
            and f.following_id = activities.actor_id
        )
      )
    $policy$;
  end if;

  -- Notifications: hanya milik sendiri.
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'notifications'
      and policyname = 'notifications_select_own'
  ) then
    execute $policy$
      create policy "notifications_select_own"
      on public.notifications
      for select
      to authenticated
      using (user_id = (select auth.uid()))
    $policy$;
  end if;

  -- User hanya boleh mengubah status read notifikasinya sendiri.
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'notifications'
      and policyname = 'notifications_update_own'
  ) then
    execute $policy$
      create policy "notifications_update_own"
      on public.notifications
      for update
      to authenticated
      using (user_id = (select auth.uid()))
      with check (user_id = (select auth.uid()))
    $policy$;
  end if;
end
$$;


-- ================================================= TRIGGER: REVIEW ACTIVITY =

-- Rating tanpa judul/konten → RATING_CREATED.
-- Review dengan judul/konten → REVIEW_CREATED.
-- Soft delete tidak menghasilkan aktivitas baru.

create or replace function public.trg_review_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    -- Review yang di-soft-delete tidak menghasilkan aktivitas.
    if new.deleted_at is not null
       and old.deleted_at is null then
      return new;
    end if;

    -- Tidak ada perubahan rating/judul/konten.
    if new.rating is not distinct from old.rating
       and new.title is not distinct from old.title
       and new.content is not distinct from old.content then
      return new;
    end if;
  end if;

  if new.rating is not null
     and coalesce(new.title, '') = ''
     and coalesce(new.content, '') = '' then

    insert into public.activities (
      actor_id,
      book_id,
      review_id,
      activity_type
    )
    values (
      new.user_id,
      new.book_id,
      new.id,
      'RATING_CREATED'
    );

  else

    insert into public.activities (
      actor_id,
      book_id,
      review_id,
      activity_type
    )
    values (
      new.user_id,
      new.book_id,
      new.id,
      'REVIEW_CREATED'
    );

  end if;

  return new;
end
$$;


do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'trg_reviews_activity'
      and tgrelid = 'public.reviews'::regclass
  ) then
    create trigger trg_reviews_activity
      after insert or update on public.reviews
      for each row
      execute function public.trg_review_activity();
  end if;
end
$$;


-- ================================================ TRIGGER: LIBRARY ACTIVITY =

-- Hanya entri PUBLIC yang menghasilkan aktivitas.
-- PRIVATE → PUBLIC: buat aktivitas sesuai status/progress saat ini.
-- PUBLIC → PRIVATE: hapus aktivitas library milik actor/book tersebut.
-- DELETE: hapus aktivitas library terkait.
-- Perubahan status/progress pada entri PRIVATE tidak menghasilkan aktivitas.

create or replace function public.trg_library_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type public.activity_type;
  v_was_public boolean := false;
  v_is_public boolean := false;
begin
  if tg_op = 'DELETE' then
    if old.visibility = 'PUBLIC' then
      delete from public.activities
      where actor_id = old.user_id
        and book_id = old.book_id
        and activity_type in (
          'BOOK_ADDED',
          'BOOK_STARTED',
          'BOOK_FINISHED',
          'READING_PROGRESS_UPDATED'
        );
    end if;

    return old;
  end if;

  if tg_op = 'UPDATE' then
    v_was_public := old.visibility = 'PUBLIC';
  end if;

  v_is_public := new.visibility = 'PUBLIC';

  -- Jika sebelumnya PUBLIC lalu menjadi PRIVATE, bersihkan aktivitas.
  if v_was_public and not v_is_public then
    delete from public.activities
    where actor_id = new.user_id
      and book_id = new.book_id
      and activity_type in (
        'BOOK_ADDED',
        'BOOK_STARTED',
        'BOOK_FINISHED',
        'READING_PROGRESS_UPDATED'
      );

    return new;
  end if;

  -- Entri PRIVATE tidak menghasilkan aktivitas.
  if not v_is_public then
    return new;
  end if;

  -- INSERT atau perubahan PRIVATE → PUBLIC.
  if tg_op = 'INSERT' or not v_was_public then
    if new.status = 'READING' then
      v_type := 'BOOK_STARTED';
    elsif new.status = 'FINISHED' then
      v_type := 'BOOK_FINISHED';
    else
      v_type := 'BOOK_ADDED';
    end if;

  else
    -- Perubahan status.
    if new.status is distinct from old.status then
      if new.status = 'READING' then
        v_type := 'BOOK_STARTED';
      elsif new.status = 'FINISHED' then
        v_type := 'BOOK_FINISHED';
      elsif old.status = 'READING'
            and new.status <> 'FINISHED' then
        return new;
      else
        v_type := 'BOOK_ADDED';
      end if;

    -- Perubahan progress.
    elsif new.progress is distinct from old.progress then
      v_type := 'READING_PROGRESS_UPDATED';

    else
      return new;
    end if;
  end if;

  insert into public.activities (
    actor_id,
    book_id,
    activity_type
  )
  values (
    new.user_id,
    new.book_id,
    v_type
  );

  return new;
end
$$;


do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'trg_library_activity'
      and tgrelid = 'public.library_entries'::regclass
  ) then
    create trigger trg_library_activity
      after insert or update or delete on public.library_entries
      for each row
      execute function public.trg_library_activity();
  end if;
end
$$;


-- =============================================== TRIGGER: LIKE NOTIFICATION =

create or replace function public.trg_like_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  select r.user_id
  into v_owner
  from public.reviews r
  where r.id = new.review_id
    and r.deleted_at is null;

  if v_owner is null or v_owner = new.user_id then
    return new;
  end if;

  insert into public.notifications (
    user_id,
    notification_type,
    actor_id,
    review_id
  )
  values (
    v_owner,
    'REVIEW_LIKED',
    new.user_id,
    new.review_id
  );

  return new;
end
$$;


do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'trg_likes_notification'
      and tgrelid = 'public.likes'::regclass
  ) then
    create trigger trg_likes_notification
      after insert on public.likes
      for each row
      execute function public.trg_like_notification();
  end if;
end
$$;


-- ============================================= TRIGGER: COMMENT NOTIFICATION =

create or replace function public.trg_comment_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  select r.user_id
  into v_owner
  from public.reviews r
  where r.id = new.review_id
    and r.deleted_at is null;

  if v_owner is null or v_owner = new.user_id then
    return new;
  end if;

  insert into public.notifications (
    user_id,
    notification_type,
    actor_id,
    review_id,
    comment_id
  )
  values (
    v_owner,
    'REVIEW_COMMENTED',
    new.user_id,
    new.review_id,
    new.id
  );

  return new;
end
$$;


do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'trg_comments_notification'
      and tgrelid = 'public.comments'::regclass
  ) then
    create trigger trg_comments_notification
      after insert on public.comments
      for each row
      execute function public.trg_comment_notification();
  end if;
end
$$;


-- =============================================== TRIGGER: FOLLOW NOTIFICATION =

create or replace function public.trg_follow_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notifications (
    user_id,
    notification_type,
    actor_id
  )
  values (
    new.following_id,
    'NEW_FOLLOWER',
    new.follower_id
  );

  return new;
end
$$;


do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'trg_follows_notification'
      and tgrelid = 'public.follows'::regclass
  ) then
    create trigger trg_follows_notification
      after insert on public.follows
      for each row
      execute function public.trg_follow_notification();
  end if;
end
$$;


-- ================================================================ VERIFY ===

-- 1. RLS harus aktif pada kedua tabel.
select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled
from pg_class c
where c.oid in (
  'public.activities'::regclass,
  'public.notifications'::regclass
)
order by c.relname;

-- Harapan: 2 baris, keduanya true.


-- 2. Policy activities hanya SELECT following.
select
  tablename,
  policyname,
  cmd,
  roles
from pg_policies
where schemaname = 'public'
  and tablename in ('activities', 'notifications')
order by tablename, policyname;

-- Harapan:
-- activities: activities_select_following (SELECT)
-- notifications: notifications_select_own (SELECT)
-- notifications: notifications_update_own (UPDATE)
-- Tidak ada policy INSERT/DELETE.


-- 3. Trigger aktivitas dan notifikasi.
select
  c.relname as table_name,
  t.tgname as trigger_name
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'reviews',
    'library_entries',
    'likes',
    'comments',
    'follows'
  )
  and not t.tgisinternal
order by c.relname, t.tgname;

-- Harapan: 7 baris:
-- 2 trigger updated_at dari skrip 002/003
-- 5 trigger fungsional:
-- trg_reviews_activity
-- trg_library_activity
-- trg_likes_notification
-- trg_comments_notification
-- trg_follows_notification


-- 4. Indeks activities dan notifications.
select tablename, indexname
from pg_indexes
where schemaname = 'public'
  and tablename in ('activities', 'notifications')
order by tablename, indexname;

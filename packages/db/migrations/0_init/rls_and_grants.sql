-- ============================================
-- RLS & Grant untuk tabel baru dari Prisma Migrate
-- Tabel lama (SQL 001–005) dikecualikan — dikelola SQL manual
-- ============================================

-- ============================================
-- book_tags — full access for authenticated users (no user_id column, global tags)
-- ============================================
ALTER TABLE public.book_tags ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.book_tags FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.book_tags TO authenticated;

CREATE POLICY book_tags_all_auth ON public.book_tags
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- ============================================
-- book_categories — full access for authenticated users (no user_id column, global categories)
-- ============================================
ALTER TABLE public.book_categories ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.book_categories FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.book_categories TO authenticated;

CREATE POLICY book_categories_all_auth ON public.book_categories
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- ============================================
-- reading_goals — RLS: user hanya bisa lihat/mengubah goal miliknya sendiri
-- ============================================
ALTER TABLE public.reading_goals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.reading_goals FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.reading_goals TO authenticated;

CREATE POLICY reading_goals_select_own ON public.reading_goals
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()::text);

CREATE POLICY reading_goals_insert_own ON public.reading_goals
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid()::text);

CREATE POLICY reading_goals_update_own ON public.reading_goals
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()::text)
  WITH CHECK (user_id = auth.uid()::text);

CREATE POLICY reading_goals_delete_own ON public.reading_goals
  FOR DELETE TO authenticated
  USING (user_id = auth.uid()::text);

-- ============================================
-- book_quotes — RLS: user hanya bisa lihat/mengubah quote miliknya sendiri
-- ============================================
ALTER TABLE public.book_quotes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.book_quotes FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.book_quotes TO authenticated;

CREATE POLICY book_quotes_select_own ON public.book_quotes
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()::text);

CREATE POLICY book_quotes_insert_own ON public.book_quotes
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid()::text);

CREATE POLICY book_quotes_update_own ON public.book_quotes
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()::text)
  WITH CHECK (user_id = auth.uid()::text);

CREATE POLICY book_quotes_delete_own ON public.book_quotes
  FOR DELETE TO authenticated
  USING (user_id = auth.uid()::text);
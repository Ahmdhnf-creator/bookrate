-- ============================================
-- RLS & Grant untuk tabel baru dari Prisma Migrate
-- Tabel lama (SQL 001–005) dikecualikan — dikelola SQL manual
-- ============================================

-- ============================================
-- book_tags — readable by authenticated users
-- ============================================
ALTER TABLE public.book_tags ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.book_tags FROM anon, authenticated;
GRANT SELECT ON TABLE public.book_tags TO anon, authenticated;

-- ============================================
-- book_categories — readable by authenticated users
-- ============================================
ALTER TABLE public.book_categories ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.book_categories FROM anon, authenticated;
GRANT SELECT ON TABLE public.book_categories TO anon, authenticated;

-- ============================================
-- reading_goals — RLS: user hanya bisa lihat/mengubah goal miliknya sendiri
-- ============================================
ALTER TABLE public.reading_goals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.reading_goals FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.reading_goals TO authenticated;

CREATE POLICY reading_goals_select_own ON public.reading_goals
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY reading_goals_insert_own ON public.reading_goals
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY reading_goals_update_own ON public.reading_goals
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY reading_goals_delete_own ON public.reading_goals
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ============================================
-- book_quotes — RLS: user hanya bisa lihat/mengubah quote miliknya sendiri
-- ============================================
ALTER TABLE public.book_quotes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.book_quotes FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.book_quotes TO authenticated;

CREATE POLICY book_quotes_select_own ON public.book_quotes
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY book_quotes_insert_own ON public.book_quotes
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY book_quotes_update_own ON public.book_quotes
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY book_quotes_delete_own ON public.book_quotes
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());
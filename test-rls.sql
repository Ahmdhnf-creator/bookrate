-- Test RLS di Supabase SQL Editor
-- Jalankan semua baris ini sekaligus

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub": "user-123", "role": "authenticated"}', true);

-- Test 3: INSERT dengan nilai id secara manual
INSERT INTO book_tags (id, book_id, tag_name) VALUES ('test-id-001', 'book-test-001', 'uji-coba');
SELECT * FROM book_tags WHERE book_id = 'book-test-001';

-- Test 4: DELETE
DELETE FROM book_tags WHERE book_id = 'book-test-001';

-- Alternatif INSERT dengan UUID otomatis
-- INSERT INTO book_tags (id, book_id, tag_name) VALUES (gen_random_uuid()::text, 'book-test-002', 'uji-coba-2');
-- SELECT * FROM book_tags WHERE book_id = 'book-test-002';
-- DELETE FROM book_tags WHERE book_id = 'book-test-002';

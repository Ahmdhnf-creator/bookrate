# BOOKRATE
## Product Requirements Document (PRD)

**Version:** 1.0  
**Product:** Social Reading Platform  
**Platforms:** Web, Android, iOS  
**Status:** Initial Product Specification

---

## 1. Product Overview

BookRate adalah platform sosial untuk pembaca yang memungkinkan pengguna mencatat perjalanan membaca, memberikan rating dan review buku, membangun profil sebagai reader, serta terhubung dengan pembaca lainnya.

BookRate menggabungkan personal book tracking dan social interaction dalam satu ekosistem.

### Product Vision

To connect readers through books, ideas, and shared experiences.

### Product Mission

- Membantu pengguna mengelola perjalanan membaca.
- Menyediakan ruang untuk berbagi opini dan review buku.
- Menghubungkan pembaca dengan minat yang sama.
- Menciptakan komunitas pembaca yang aktif dan saling mendukung.

### Core Value

1. Read — Track your reading journey.
2. Rate — Share your thoughts and opinions.
3. Connect — Connect with other readers.
4. Discover — Explore books through people.

---

## 2. Target Users

### Primary Users

**A. Casual Readers**
- Membaca buku sesekali.
- Ingin mencatat buku yang telah dibaca.
- Ingin menemukan buku baru.

**B. Active Readers**
- Membaca buku secara rutin.
- Suka memberikan rating dan review.
- Ingin membangun koleksi digital.

**C. Book Enthusiasts**
- Memiliki preferensi genre tertentu.
- Suka berdiskusi tentang buku.
- Ingin mengikuti pembaca dengan minat serupa.

**D. Beginner Readers**
- Baru mulai membangun kebiasaan membaca.
- Membutuhkan referensi buku.
- Membutuhkan perspektif dari pembaca lain.

---

## 3. Product Scope

BookRate memiliki dua platform utama:

### Web Application
- Responsive desktop.
- Responsive tablet.
- Responsive mobile browser.
- Public reader profile.
- Book discovery.
- Social feed.
- Personal library.

### Mobile Application
- Android.
- iOS.
- Social feed.
- Book discovery.
- Personal library.
- Reader profile.
- Push notifications.

Kedua platform menggunakan backend, authentication, dan database yang sama.

---

## 4. Functional Requirements

### FR-01: Authentication

Pengguna dapat:
- Register menggunakan email dan password.
- Login.
- Logout.
- Reset password.
- Memverifikasi email.
- Mengelola informasi akun.

Persyaratan:
- Email harus unik.
- Username harus unik.
- Password disimpan dalam bentuk hash.
- Session harus aman.
- Endpoint privat membutuhkan autentikasi.

### FR-02: User Profile

Setiap pengguna memiliki profil publik.

Informasi profil:
- Avatar.
- Cover profile (opsional).
- Display name.
- Username.
- Bio.
- Join date.
- Favorite genres.
- Books read.
- Reviews count.
- Followers count.
- Following count.
- Currently reading.
- Recently finished.

Pengguna dapat:
- Mengedit profil sendiri.
- Mengatur foto profil.
- Mengatur bio.
- Mengatur genre favorit.
- Mengatur visibilitas aktivitas tertentu.
- Melihat profil pengguna lain.

Profil bersifat public by default.

### FR-03: Book Search

Pengguna dapat mencari buku berdasarkan:
- Judul.
- Penulis.
- ISBN.
- Publisher.
- Genre.

Sumber metadata:
- Google Books API.
- Open Library sebagai fallback.

Data buku yang disimpan:
- Title.
- Authors.
- Description.
- ISBN-10.
- ISBN-13.
- Publisher.
- Published date.
- Cover image.
- Categories.
- External identifiers.

### FR-04: Book Detail

Setiap buku memiliki halaman detail berisi:
- Cover.
- Title.
- Author.
- Description.
- Publisher.
- ISBN.
- Average BookRate rating.
- Total ratings.
- Rating distribution.
- Community reviews.
- Popular reviewers.

Pengguna dapat menambahkan buku ke personal library.

### FR-05: Personal Library

Setiap pengguna mempunyai koleksi buku pribadi.

Reading status:

1. WANT_TO_READ
2. READING
3. FINISHED

Fitur:
- Add book.
- Remove book.
- Change reading status.
- Update reading progress.
- Set start date.
- Set finish date.
- Add personal notes.

Reading progress menggunakan persentase 0–100.

### FR-06: Rating and Review

Pengguna dapat memberikan rating 0.5 sampai 5.0.

Interval rating adalah 0.5.

Contoh:
- 0.5
- 1.0
- 1.5
- 2.0
- 2.5
- 3.0
- 3.5
- 4.0
- 4.5
- 5.0

Review memiliki:
- Rating.
- Review title (optional).
- Review content (optional).
- Spoiler flag.
- Created date.
- Updated date.

Business rules:
- Satu pengguna hanya memiliki satu review aktif per buku.
- Review dapat diedit.
- Review dapat dihapus.
- Rating harus berada pada interval 0.5.
- Rating dan review dapat dibuat tanpa tulisan review.
- Rating rata-rata dihitung dari review BookRate.
- Review yang dihapus tidak masuk perhitungan rating.

### FR-07: Follow System

Pengguna dapat:
- Follow pengguna lain.
- Unfollow pengguna lain.
- Melihat followers.
- Melihat following.
- Melihat mutual followers.

Rules:
- Tidak boleh follow diri sendiri.
- Tidak boleh duplicate follow.
- Relasi follow bersifat satu arah.
- Profil tetap dapat dilihat tanpa harus follow.

### FR-08: Home Feed

Home feed hanya menampilkan aktivitas dari pengguna yang diikuti.

Activity types:
- BOOK_ADDED.
- BOOK_STARTED.
- BOOK_FINISHED.
- REVIEW_CREATED.
- RATING_CREATED.
- READING_PROGRESS_UPDATED.

Setiap feed item dapat menampilkan:
- User information.
- Activity description.
- Book information.
- Rating.
- Review preview.
- Timestamp.
- Like count.
- Comment count.

Feed tidak menampilkan aktivitas dari pengguna yang tidak diikuti.

### FR-09: Social Interaction

Pengguna dapat:
- Like review.
- Unlike review.
- Comment on review.
- Delete own comment.
- Save review.
- Share book or review.
- Report review.
- Block user.

### FR-10: Notification

Jenis notifikasi:
- NEW_FOLLOWER.
- REVIEW_LIKED.
- REVIEW_COMMENTED.
- NEW_COMMENT_REPLY (future).
- READING_MILESTONE (future).

Pengguna dapat:
- Melihat notifikasi.
- Menandai notifikasi sudah dibaca.
- Menandai semua notifikasi sudah dibaca.

### FR-11: Search Readers

Pengguna dapat mencari reader berdasarkan:
- Username.
- Display name.
- Favorite genres.

Halaman Readers menampilkan:
- Suggested readers.
- Popular readers.
- New readers.
- Readers by genre.

Recommended Readers menggunakan algoritma berbasis kesamaan minat dan aktivitas, bukan sekadar jumlah buku.

### FR-12: Privacy and Moderation

- Public profile secara default.
- Pengguna dapat menyembunyikan aktivitas tertentu.
- Pengguna dapat menyembunyikan koleksi tertentu.
- Pengguna dapat memblokir akun.
- Pengguna dapat melaporkan konten.
- Admin dapat meninjau laporan.
- Admin dapat menyembunyikan konten yang melanggar aturan.

---

## 5. Non-Functional Requirements

### Performance
- Halaman utama harus responsif.
- Feed menggunakan pagination.
- Book search menggunakan debounce.
- Cover menggunakan image optimization.
- Database memiliki index pada kolom pencarian dan relasi utama.

### Security
- Secure password hashing.
- Authentication middleware.
- Authorization checks.
- Input validation.
- Rate limiting.
- Protection against SQL injection.
- Secure session management.
- Environment secrets tidak boleh masuk repository.

### Scalability
- Backend API terpisah secara logis dari frontend.
- Database menggunakan relasi yang terstruktur.
- Aktivitas feed disimpan sebagai data terpisah.
- Rekomendasi dapat dikembangkan tanpa mengubah fondasi database.

### Compatibility
- Modern desktop browsers.
- Android.
- iOS.
- Responsive layouts.

### Accessibility
- Semantic elements.
- Keyboard navigation untuk web.
- Accessible labels.
- Adequate color contrast.

---

## 6. MVP Success Metrics

Indikator keberhasilan MVP:

- Registration completion rate.
- Percentage of users completing their profiles.
- Books added per active user.
- Reviews created per active user.
- Follow actions per active user.
- Weekly active readers.
- Feed engagement rate.
- Returning users.

Angka target ditentukan setelah tersedia baseline dari pengguna beta.

---

## 7. Out of Scope for MVP

Fitur berikut belum menjadi bagian MVP:

- Direct messaging.
- Group reading rooms.
- Real-time chat.
- AI book recommendation.
- Paid membership.
- Marketplace buku.
- Book purchasing.
- Reading challenges kompleks.
- Advanced leaderboard.
- Gamification lanjutan.

---

## 8. Product Definition of Done

MVP dinyatakan selesai apabila:
- Pengguna dapat register dan login.
- Pengguna dapat mengelola profil publik.
- Pengguna dapat mencari dan melihat detail buku.
- Pengguna dapat mengelola reading library.
- Pengguna dapat memberikan rating dan review.
- Pengguna dapat follow dan unfollow.
- Home feed menampilkan aktivitas following.
- Pengguna dapat like dan comment.
- Notifikasi dasar berjalan.
- Web dan mobile menggunakan data yang sama.
- Authorization dan privacy rules telah diuji.
- Critical user journeys lulus pengujian.

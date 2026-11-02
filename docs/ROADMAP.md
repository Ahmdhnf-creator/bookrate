# BookRate — Development Roadmap

## Tujuan

Roadmap ini mengatur urutan pengembangan BookRate, Social Reading Platform dengan tagline **Read. Rate. Connect.**

## Prinsip Pelaksanaan

- `docs/PRD.md` adalah sumber kebenaran untuk kebutuhan produk.
- Dokumen ini adalah sumber kebenaran untuk urutan task dan quality gate.
- Kerjakan backend terlebih dahulu. Frontend tidak dimulai sebelum Task 11 selesai dan disetujui.
- Ikuti workflow Superpowers untuk setiap task: pahami PRD, roadmap, dan kondisi repo; brainstorming; spesifikasi; rencana; review dan persetujuan; implementasi; verifikasi; dokumentasi; commit; lalu lanjut ke task berikutnya.
- Jangan mengubah scope produk, urutan task, atau keputusan teknis yang belum disepakati tanpa meminta persetujuan.
- Keputusan teknis yang belum ditetapkan harus dicatat sebagai **Open Decision**, bukan diasumsikan sudah disetujui.

## Phase 1 — Backend

| Task | Nama | Estimasi |
|---|---|---:|
| 1 | Backend Project Setup | 3–4 hari |
| 2 | Database Architecture & Setup | 3–5 hari |
| 3 | Authentication & Authorization | 3–5 hari |
| 4 | User Profile & Privacy | 2–4 hari |
| 5 | Book System & External API | 4–6 hari |
| 6 | Personal Library & Reading Progress | 3–4 hari |
| 7 | Rating & Review System | 3–4 hari |
| 8 | Social System & Following | 3–4 hari |
| 9 | Activity Feed & Interaction | 4–6 hari |
| 10 | Notification, Discovery & Moderation | 5–7 hari |
| 11 | Backend Testing, Security & API Finalization | 5–7 hari |

### Backend Quality Gate

Task 11 harus selesai dan disetujui sebelum pekerjaan frontend dimulai. Gate mencakup pengujian, pemeriksaan keamanan dan otorisasi, konsistensi API, serta dokumentasi yang diperlukan.

## Phase 2 — Frontend

| Task | Nama | Estimasi |
|---|---|---:|
| 12 | Frontend Project Setup & Design System | 3–5 hari |
| 13 | Web Development — Next.js | 10–15 hari |
| 14 | Mobile Development — Expo | 10–15 hari |
| 15 | API Integration & Cross-platform Testing | 5–8 hari |

## Phase 3 — Launch

| Task | Nama | Estimasi |
|---|---|---:|
| 16 | Deployment & Launch | 3–5 hari |

## Estimasi Total

**69–104 hari kerja aktif** untuk satu developer yang fokus. Estimasi ini tidak mencakup waktu tunggu dari layanan eksternal atau proses review app store.

## Urutan Integrasi Fitur

Untuk setiap fitur backend, ikuti urutan:

1. Database migration
2. Business logic
3. API route, validation, dan authorization
4. Tests
5. Documentation
6. Frontend integration setelah fase backend disetujui

## Open Decisions

Keputusan berikut belum dianggap final dan perlu ditinjau sebelum implementasi yang bergantung padanya:

- Pilihan dan bentuk backend final.
- Target deployment dan arsitektur hosting.
- Detail teknis lain yang belum ditetapkan di PRD atau disetujui secara eksplisit.

## Aturan Memulai Task

Sebelum mengerjakan task, periksa `docs/PRD.md`, roadmap ini, dan kondisi repository saat ini. Jangan langsung mengimplementasikan task berikutnya tanpa menyelesaikan review dan persetujuan task yang sedang berjalan.
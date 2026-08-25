# 🏗️ Arsitektur Sistem — Tertib Sekolah

## 1. Gambaran Umum

**Tertib Sekolah** adalah aplikasi mobile & multiplatform untuk manajemen kedisiplinan siswa (khususnya keterlambatan). Dibangun menggunakan arsitektur **Client-Server** dengan:

- **Frontend**: Flutter (Dart) — cross-platform (Android, iOS, Web, Linux, macOS, Windows)
- **Backend**: Supabase (PostgreSQL) — BaaS (Backend-as-a-Service)
- **Realtime**: Supabase Realtime (WebSocket-based)
- **Serverless**: Supabase Edge Functions (Deno/TypeScript)

```
┌─────────────────────────────────────────────────────────┐
│                    CLIENT LAYER                         │
│                                                         │
│   ┌──────────────────────────────────────────────────┐  │
│   │        Flutter Application (Dart)                │  │
│   │  ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │  │
│   │  │  Admin   │ │  Guru    │ │     Siswa        │  │  │
│   │  │Dashboard │ │Dashboard │ │   Dashboard      │  │  │
│   │  └──────────┘ └──────────┘ └──────────────────┘  │  │
│   │              Screens / UI Layer                  │  │
│   └──────────────────────────────────────────────────┘  │
│                         │                               │
│   ┌──────────────────────────────────────────────────┐  │
│   │        Core Services Layer                       │  │
│   │  ┌──────────────┐  ┌──────────────────────────┐  │  │
│   │  │ AuthService  │  │   SupabaseConfig         │  │  │
│   │  └──────────────┘  └──────────────────────────┘  │  │
│   └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                           │ HTTPS / WebSocket
                           ▼
┌─────────────────────────────────────────────────────────┐
│                    SUPABASE PLATFORM                    │
│                                                         │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │ Supabase    │  │  Realtime    │  │  Edge Fns     │  │
│  │   Auth      │  │  (WebSocket) │  │  (Deno/TS)    │  │
│  └─────────────┘  └──────────────┘  └───────────────┘  │
│                           │                             │
│  ┌─────────────────────────────────────────────────┐    │
│  │             PostgreSQL Database                 │    │
│  │  ┌──────────┐ ┌───────────┐ ┌───────────────┐  │    │
│  │  │ profiles │ │ terlambat │ │ detail_siswa  │  │    │
│  │  └──────────┘ └───────────┘ └───────────────┘  │    │
│  │          ┌──────────────────┐                  │    │
│  │          │  bukti_evaluasi  │                  │    │
│  │          └──────────────────┘                  │    │
│  │   (+ Triggers, Functions, RLS Policies)        │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │            Supabase Storage                     │    │
│  │     (Foto bukti tugas evaluasi)                │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Stack Teknologi

### Frontend (Flutter)

| Teknologi | Versi | Kegunaan |
|-----------|-------|----------|
| Flutter / Dart | SDK ^3.11.5 | Framework utama aplikasi |
| supabase_flutter | ^2.9.1 | Client Supabase (Auth, DB, Realtime) |
| google_fonts | ^8.1.0 | Tipografi (Manrope & Inter) |
| intl | ^0.19.0 | Format tanggal & lokalisasi bahasa Indonesia |
| image_picker | ^1.1.2 | Mengambil foto dari kamera/galeri |
| flutter_image_compress | ^2.3.0 | Kompresi foto sebelum upload |
| url_launcher | ^6.2.5 | Membuka URL/link eksternal |

### Backend (Supabase)

| Komponen | Teknologi | Kegunaan |
|----------|-----------|----------|
| Database | PostgreSQL 17 | Penyimpanan data utama |
| Auth | Supabase Auth (JWT) | Autentikasi email & password |
| Realtime | PostgreSQL WAL + WebSocket | Sinkronisasi data real-time |
| Edge Functions | Deno (TypeScript) | Logika server-side khusus admin |
| Storage | Supabase Storage | Penyimpanan foto bukti evaluasi |

### Infrastruktur

- **Region Database**: Asia Pacific (Seoul: `ap-northeast-2`)
- **Region Aktif (V2)**: Asia Pacific (Singapore: `ap-southeast-1`)
- **Project Aktif**: `TertibSekolahV2` (ID: `gaiagxlmtancqreovmai`)

---

## 3. Struktur Folder Project

```
TertibSekolah/
├── Frontend/                          # Aplikasi Flutter
│   ├── lib/
│   │   ├── main.dart                  # Entry point + inisialisasi Supabase
│   │   ├── core/
│   │   │   ├── auth_service.dart      # Service autentikasi (login/logout)
│   │   │   ├── supabase_config.dart   # Konfigurasi environment Supabase
│   │   │   └── tardiness_service.dart # Service update level keterlambatan
│   │   ├── screens/
│   │   │   ├── login_screen.dart              # Halaman login
│   │   │   ├── admin_dashboard_screen.dart    # Dashboard Admin
│   │   │   ├── guru_dashboard_screen.dart     # Dashboard Guru
│   │   │   ├── siswa_dashboard_screen.dart    # Dashboard Siswa
│   │   │   ├── input_keterlambatan_screen.dart # Form input keterlambatan
│   │   │   ├── evaluasi_tugas_screen.dart     # Daftar tugas evaluasi
│   │   │   ├── form_evaluasi_tugas_screen.dart # Form penilaian tugas guru
│   │   │   ├── data_siswa_screen.dart         # Daftar data siswa
│   │   │   └── detail_siswa_screen.dart       # Detail profil siswa
│   │   └── theme/
│   │       ├── app_colors.dart        # Definisi palet warna aplikasi
│   │       └── app_theme.dart         # Konfigurasi tema Material 3
│   ├── assets/
│   │   └── icon/                      # App icon
│   ├── android/                       # Platform-specific Android config
│   ├── ios/                           # Platform-specific iOS config
│   ├── web/                           # Platform-specific Web config
│   ├── .env                           # ENV vars (gitignored)
│   ├── .env.example                   # Contoh ENV vars
│   └── pubspec.yaml                   # Dependensi Flutter
│
├── supabase/
│   └── functions/
│       ├── create-user/index.ts       # Edge Function: buat user baru
│       └── delete-user/index.ts       # Edge Function: hapus user
│
└── Docs/                              # Folder dokumentasi (ini)
```

---

## 4. Pola Arsitektur

### Layer Architecture (Simplified)

```
┌─────────────────────────────────┐
│         UI Layer (Screens)      │  ← Tampilan & interaksi pengguna
├─────────────────────────────────┤
│       Service Layer (Core)      │  ← Logika bisnis (AuthService, dll)
├─────────────────────────────────┤
│      Data Layer (Supabase)      │  ← Akses database langsung via client
└─────────────────────────────────┘
```

> **Catatan**: Proyek ini menggunakan arsitektur yang disederhanakan tanpa state management library (seperti Provider/Riverpod/Bloc). State dikelola langsung di dalam StatefulWidget masing-masing screen.

### Data Flow

1. **Read Data**: `Screen` → `supabase.from(...).select()` → PostgreSQL → `setState()`
2. **Write Data**: `Screen` → `supabase.from(...).insert/update()` → PostgreSQL → (trigger auto-update statistik)
3. **Realtime**: PostgreSQL changes → Supabase Realtime → WebSocket → `_fetchDashboardData()`
4. **Auth**: `LoginScreen` → `AuthService.signIn()` → Supabase Auth → redirect ke dashboard sesuai role

---

## 5. Sistem Role / Peran

Aplikasi memiliki 3 jenis pengguna:

| Role | Bahasa Indonesia | Akses Utama |
|------|-----------------|-------------|
| `admin` | Administrator | Manajemen user, statistik lengkap, semua data |
| `guru` | Guru / Piket | Input keterlambatan, evaluasi tugas, lihat data siswa |
| `siswa` | Siswa | Lihat riwayat keterlambatan sendiri, upload bukti tugas |

Routing otomatis dilakukan di `LoginScreen` berdasarkan nilai field `role` pada tabel `profiles`.

---

## 6. Konfigurasi Environment

Aplikasi menggunakan **dart-define-from-file** untuk inject environment variables saat build:

```bash
flutter run --dart-define-from-file=.env
```

File `.env` (tidak di-commit ke git) berisi:
```
SUPABASE_URL=https://[project-id].supabase.co
SUPABASE_ANON_KEY=[anon-public-key]
```

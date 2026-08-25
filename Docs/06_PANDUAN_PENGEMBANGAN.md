# 🚀 Panduan Pengembangan — Tertib Sekolah

## 1. Prerequisites

Pastikan tools berikut terinstal:

| Tool | Versi Minimum | Keterangan |
|------|--------------|------------|
| Flutter | 3.x (stable) | Framework utama |
| Dart SDK | ^3.11.5 | Sudah termasuk dengan Flutter |
| Android Studio / VS Code | Latest | IDE |
| Supabase CLI | Latest | Untuk manage edge functions |
| Git | Latest | Version control |

---

## 2. Setup Project

### 2.1 Clone Repository
```bash
git clone <repository-url>
cd TertibSekolah/Frontend
```

### 2.2 Install Dependencies
```bash
flutter pub get
```

### 2.3 Konfigurasi Environment

1. Buat file `.env` di folder `Frontend/`:
```bash
cp .env.example .env
```

2. Isi file `.env` dengan credentials Supabase:
```
SUPABASE_URL=https://gaiagxlmtancqreovmai.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
```

> **Dapatkan credentials** dari: [Supabase Dashboard](https://supabase.com/dashboard) → Project Settings → API

### 2.4 Verifikasi Setup
```bash
flutter doctor
flutter pub outdated
```

---

## 3. Menjalankan Aplikasi

### Via VS Code (Direkomendasikan)

Tekan `F5` → pilih konfigurasi **"Debug (dengan .env)"**

Konfigurasi sudah tersedia di `.vscode/launch.json`:
```json
{
  "name": "Debug (dengan .env)",
  "args": ["--dart-define-from-file=.env"]
}
```

### Via Terminal
```bash
# Development (dengan .env)
flutter run --dart-define-from-file=.env

# Target platform tertentu
flutter run -d android --dart-define-from-file=.env
flutter run -d chrome --dart-define-from-file=.env
flutter run -d linux --dart-define-from-file=.env
```

---

## 4. Build Aplikasi

```bash
# Android APK
flutter build apk --dart-define-from-file=.env

# Android App Bundle (untuk Google Play)
flutter build appbundle --dart-define-from-file=.env

# Web
flutter build web --dart-define-from-file=.env

# Linux
flutter build linux --dart-define-from-file=.env
```

---

## 5. Struktur Kode & Konvensi

### Naming Convention

| Jenis | Konvensi | Contoh |
|-------|----------|--------|
| File | `snake_case.dart` | `guru_dashboard_screen.dart` |
| Kelas | `PascalCase` | `GuruDashboardScreen` |
| Fungsi/Method | `camelCase` | `_fetchDashboardData()` |
| Variabel | `camelCase` | `_pendingTaskCount` |
| Konstanta | `camelCase` | `supabase` (global accessor) |

### Penambahan Screen Baru

1. Buat file baru di `lib/screens/`
2. Import warna dari `theme/app_colors.dart`
3. Ikuti pattern yang sudah ada (StatefulWidget + initState untuk fetch)
4. Daftarkan di screen yang memanggilnya (tidak ada router global)

### Query Supabase

```dart
// Gunakan shortcut global
import '../main.dart';  // contains: final supabase = Supabase.instance.client;

// Contoh query
final data = await supabase
    .from('terlambat')
    .select('*, profiles!inner(full_name)')
    .eq('user_id', userId)
    .order('created_at', ascending: false);
```

---

## 6. Supabase Edge Functions

### Setup Supabase CLI
```bash
npm install -g supabase
supabase login
supabase link --project-ref gaiagxlmtancqreovmai
```

### Development Lokal
```bash
# Jalankan functions secara lokal
supabase functions serve

# Test function
curl -i --location --request POST 'http://localhost:54321/functions/v1/create-user' \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{"email":"test@test.com","password":"pass123","nama":"Test User","role":"guru"}'
```

### Deploy ke Production
```bash
supabase functions deploy create-user
supabase functions deploy delete-user
```

---

## 7. Panduan Penambahan Fitur

### Menambah Field Baru ke Database

1. Buat SQL migration:
```sql
ALTER TABLE public.terlambat ADD COLUMN nama_field tipe_data DEFAULT nilai_default;
```

2. Jalankan via Supabase Dashboard → SQL Editor, atau:
```bash
supabase db push
```

3. Update kode Flutter yang query/insert/update tabel tersebut

### Menambah Role Baru

1. Update enum `user_role_enum` di database
2. Update validasi di `create-user/index.ts`
3. Update `AuthService` di Flutter untuk handle role baru
4. Update routing di `LoginScreen`
5. Tambahkan RLS policies untuk role baru

---

## 8. Troubleshooting

### ❌ "ENV VARS TIDAK DITEMUKAN"
**Solusi**: Pastikan menjalankan dengan `--dart-define-from-file=.env` atau gunakan config VS Code yang sudah ada.

### ❌ Login berhasil tapi tidak ada data
**Kemungkinan**: User ada di Auth tapi tidak ada di tabel `profiles`.  
**Solusi**: Insert manual ke `profiles` atau pastikan trigger `handle_new_user` sudah aktif.

### ❌ Realtime tidak berjalan
**Kemungkinan**: Channel sudah expired atau koneksi terputus.  
**Solusi**: Cek `_dashboardChannel?.unsubscribe()` di `dispose()` dan `_setupRealtime()` di `initState()`.

### ❌ Edge Function error "Unauthorized"
**Kemungkinan**: Token JWT sudah expired atau tidak valid.  
**Solusi**: Logout dan login ulang untuk mendapat token baru.

### ❌ Upload foto gagal
**Kemungkinan**: RLS Storage belum dikonfigurasi atau bucket belum ada.  
**Solusi**: Pastikan bucket `bukti-tugas` (atau sesuai nama yang digunakan) sudah ada dan RLS-nya mengizinkan upload dari user yang terautentikasi.

---

## 9. Referensi

| Sumber | Link |
|--------|------|
| Flutter Documentation | https://docs.flutter.dev |
| Supabase Documentation | https://supabase.com/docs |
| Supabase Flutter SDK | https://pub.dev/packages/supabase_flutter |
| Material Design 3 | https://m3.material.io |
| Google Fonts (Flutter) | https://pub.dev/packages/google_fonts |

---

## 10. Informasi Project

| Item | Detail |
|------|--------|
| Nama Project | Tertib Sekolah |
| Versi Aplikasi | 1.0.0+1 |
| Platform Target | Android, iOS, Web, Linux, macOS, Windows |
| Bahasa | Dart (Flutter) + TypeScript (Edge Functions) |
| Database | PostgreSQL 17 (via Supabase) |
| Supabase Project (Aktif) | TertibSekolahV2 (`gaiagxlmtancqreovmai`) |
| Supabase Region | Asia Pacific - Singapore |

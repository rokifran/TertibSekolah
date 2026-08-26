# 🚀 Panduan Pengembangan — Tertib Sekolah

## 1. Prerequisites

Pastikan tools berikut terinstal:

| Tool | Versi Minimum | Keterangan |
|------|--------------|------------|
| Flutter | 3.x (stable) | Framework utama |
| Dart SDK | ^3.11.5 | Sudah termasuk dengan Flutter |
| Android Studio / VS Code | Latest | IDE |
| Supabase CLI | Latest | Untuk manage edge functions & migrasi |
| Git | Latest | Version control |
| Python | 3.9+ | *(Opsional)* Untuk training model Decision Tree |

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
SUPABASE_URL=https://your_project_id.supabase.co
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

### Menggunakan DecisionTreeService

```dart
import '../core/decision_tree_service.dart';

// 1. Minta prediksi
final prediction = await DecisionTreeService.predict(
  nilai: nilaiController,
  kelengkapan: isLengkap,
  kesesuaian: isSesuai,
);

// 2. Submit evaluasi (setelah guru memutuskan)
await DecisionTreeService.submitEvaluation(
  terlambatId: terlambatId,
  nilai: nilai,
  kelengkapan: kelengkapan,
  kesesuaian: kesesuaian,
  keputusanGuru: 'selesai',  // atau 'revisi'
  prediksiModel: prediction.modelActive ? prediction.prediksi : null,
  predictionConfidence: prediction.confidence,
  modelVersion: prediction.modelVersion,
);
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

# Test create-user
curl -i --location --request POST 'http://localhost:54321/functions/v1/create-user' \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{"email":"test@test.com","password":"pass123","nama":"Test User","role":"guru"}'

# Test predict-evaluation
curl -i --location --request POST 'http://localhost:54321/functions/v1/predict-evaluation' \
  --header 'Content-Type: application/json' \
  --data '{"nilai":85,"kelengkapan":true,"kesesuaian":true}'
```

### Deploy ke Production
```bash
supabase functions deploy create-user
supabase functions deploy delete-user
supabase functions deploy predict-evaluation
supabase functions deploy submit-evaluation
```

---

## 7. Migrasi Database

Folder `supabase/migrations/` berisi SQL migration yang perlu dijalankan secara berurutan.

### Migrasi yang Ada

| File | Deskripsi |
|------|-----------|
| `20260825_decision_tree.sql` | Membuat tabel `evaluasi_tugas`, `decision_tree_models`, fungsi `record_task_evaluation`, RLS, dan view `v_dataset_decision_tree` |

### Cara Menjalankan Migrasi

```bash
# Via Supabase CLI
supabase db push

# Atau manual via Supabase Dashboard → SQL Editor
```

> **Penting**: Selalu backup database sebelum menjalankan migrasi di production.

---

## 8. ML Pipeline — Decision Tree

### Setup Python Environment

```bash
cd supabase/04_ml
pip install scikit-learn pandas matplotlib joblib
```

### Ekspor Dataset

Dataset training diekspor dari view anonim di Supabase (tidak memuat data pribadi):

```sql
-- Di Supabase Dashboard → SQL Editor
COPY (SELECT * FROM public.v_dataset_decision_tree)
TO '/tmp/dataset.csv' WITH CSV HEADER;
```

Atau via psql:
```bash
psql $DATABASE_URL -c "\COPY (SELECT * FROM v_dataset_decision_tree) TO 'dataset.csv' CSV HEADER"
```

### Training Model

```bash
python supabase/04_ml/train_decision_tree.py \
  --input dataset.csv \
  --out ./output \
  --version "dt-v1"
```

**Output yang dihasilkan**:
| File | Keterangan |
|------|------------|
| `tree.json` | Model siap upload ke DB |
| `model.joblib` | Model untuk reproducibility |
| `model_metrics.json` | Metrik: akurasi, F1, confusion matrix |
| `decision_tree.png` | Visualisasi pohon keputusan |
| `classification_report.csv` | Laporan per kelas |
| `test_predictions.csv` | Prediksi pada data test |

### Deploy Model ke Database

```sql
-- 1. Upload model baru (belum aktif)
INSERT INTO public.decision_tree_models
  (version, tree_json, training_rows, criterion, max_depth, is_active, notes)
VALUES
  ('dt-v1', '<isi tree.json sebagai jsonb>', 150, 'gini', 3, false, 'Model pertama');

-- 2. Nonaktifkan model lama (jika ada)
UPDATE public.decision_tree_models SET is_active = false WHERE is_active = true;

-- 3. Aktifkan model baru
UPDATE public.decision_tree_models SET is_active = true WHERE version = 'dt-v1';
```

> **Catatan**: Partial unique index `uq_decision_tree_one_active` menjamin hanya satu model aktif.

---

## 9. Panduan Penambahan Fitur

### Menambah Field Baru ke Database

1. Buat SQL migration:
```sql
ALTER TABLE public.terlambat ADD COLUMN nama_field tipe_data DEFAULT nilai_default;
```

2. Simpan sebagai file di `supabase/migrations/` dengan nama format `YYYYMMDD_deskripsi.sql`

3. Jalankan via Supabase Dashboard → SQL Editor, atau:
```bash
supabase db push
```

4. Update kode Flutter yang query/insert/update tabel tersebut

### Menambah Role Baru

1. Update enum `user_role_enum` di database
2. Update validasi di `create-user/index.ts`
3. Update `AuthService` di Flutter untuk handle role baru
4. Update routing di `LoginScreen`
5. Tambahkan RLS policies untuk role baru

### Menambah Edge Function Baru

1. Buat folder baru: `supabase/functions/<nama-function>/`
2. Buat `index.ts` dengan pola yang sama (CORS headers, error handling)
3. Test lokal dengan `supabase functions serve`
4. Deploy: `supabase functions deploy <nama-function>`
5. Dokumentasikan di `Docs/05_EDGE_FUNCTIONS.md`

---

## 10. Troubleshooting

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

### ❌ `predict-evaluation` mengembalikan `{ model_active: false }`
**Kemungkinan**: Belum ada model Decision Tree yang di-upload dan diaktifkan di tabel `decision_tree_models`.  
**Solusi**: Training model dengan script Python lalu upload `tree.json` ke database (lihat bagian ML Pipeline).

### ❌ `submit-evaluation` error "Hanya guru atau admin..."
**Kemungkinan**: Token yang dikirim bukan dari akun guru/admin, atau role di `profiles` tidak sesuai.  
**Solusi**: Pastikan user yang login memiliki role `guru` atau `admin` di tabel `profiles`.

### ❌ Training model gagal: "Setiap kelas minimal memerlukan 5 record"
**Kemungkinan**: Dataset belum cukup (perlu minimal 5 data per kelas `selesai` dan `revisi`).  
**Solusi**: Kumpulkan lebih banyak data evaluasi manual terlebih dahulu sebelum training.

---

## 11. Referensi

| Sumber | Link |
|--------|------|
| Flutter Documentation | https://docs.flutter.dev |
| Supabase Documentation | https://supabase.com/docs |
| Supabase Flutter SDK | https://pub.dev/packages/supabase_flutter |
| Material Design 3 | https://m3.material.io |
| Google Fonts (Flutter) | https://pub.dev/packages/google_fonts |
| scikit-learn Decision Tree | https://scikit-learn.org/stable/modules/tree.html |

---

## 12. Informasi Project

| Item | Detail |
|------|--------|
| Nama Project | Tertib Sekolah |
| Versi Aplikasi | 1.0.0+1 |
| Platform Target | Android, iOS, Web, Linux, macOS, Windows |
| Bahasa | Dart (Flutter) + TypeScript (Edge Functions) + Python (ML) |
| Database | PostgreSQL 17 (via Supabase) |
| Supabase Project (Aktif) | TertibSekolahV2 (`gaiagxlmtancqreovmai`) |
| Supabase Region | Asia Pacific - Singapore |

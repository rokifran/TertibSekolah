# 🗄️ Schema Database — Tertib Sekolah

**Project Supabase**: TertibSekolahV2  
**Project ID**: `gaiagxlmtancqreovmai`  
**Region**: Asia Pacific (Singapore)  
**Database Engine**: PostgreSQL 17  

---

## 1. Diagram Relasi Tabel (ERD)

```
┌──────────────────────────────────────────────────────────────────┐
│                      auth.users (Supabase Auth)                  │
│  id (uuid) | email | ...                                         │
└──────────────────────────────┬───────────────────────────────────┘
                               │ trigger: handle_new_user
                               │ (auto-insert ke profiles)
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                         public.profiles                           │
│  id (uuid) PK | full_name | email | role | avatar_url            │
│  created_at | updated_at                                          │
└───────────────┬──────────────────────────┬────────────────────────┘
                │                          │
                │ FK: user_id              │ FK: evaluator_id
                ▼                          ▼
┌───────────────────────────┐  ┌──────────────────────────────────┐
│     public.detail_siswa   │  │         public.terlambat          │
│  id (uuid) PK             │  │  id (uuid) PK                     │
│  user_id (uuid) FK        │  │  user_id (uuid) FK → profiles     │
│  kelas (varchar)          │  │  evaluator_id (uuid) FK→profiles  │
│  nisn (varchar)           │  │  tanggal_terlambat (date)         │
│  total_terlambat (bigint) │  │  durasi_menit (int)               │
│  total_menit_terlambat    │  │  tugas_hukuman (text)             │
│  status_disiplin (enum)   │  │  status_evaluasi (enum)           │
│  created_at | updated_at  │  │  alasan (text)                    │
└───────────────────────────┘  │  kelengkapan (boolean)            │
                               │  kesesuaian (boolean)             │
                               │  nilai (int)                      │
                               │  hasil_validasi (text)            │
                               │  created_at | updated_at          │
                               └───────────┬───────────────────────┘
                                           │
                      ┌────────────────────┴──────────────────┐
                      │ FK: terlambat_id                      │ FK: terlambat_id
                      ▼                                       ▼
       ┌───────────────────────────────────┐  ┌──────────────────────────────────────┐
       │       public.bukti_evaluasi       │  │        public.evaluasi_tugas          │
       │  id (bigint) PK                   │  │  id (uuid) PK                        │
       │  terlambat_id (uuid) FK           │  │  terlambat_id (uuid) FK              │
       │  photo_path (varchar)             │  │  evaluator_id (uuid) FK → profiles   │
       │  created_at                       │  │  nilai (smallint)                    │
       └───────────────────────────────────┘  │  kelengkapan (boolean)               │
                                              │  kesesuaian (boolean)                │
                                              │  keputusan_guru (varchar)            │
                                              │  prediksi_model (varchar)            │
                                              │  prediction_confidence (numeric)     │
                                              │  model_version (varchar) FK          │
                                              │  decision_source (varchar)           │
                                              │  created_at                          │
                                              └──────────────────────────────────────┘
                                                            │ FK: model_version
                                                            ▼
                                              ┌──────────────────────────────────────┐
                                              │     public.decision_tree_models       │
                                              │  version (varchar) PK                │
                                              │  tree_json (jsonb)                   │
                                              │  feature_names (text[])              │
                                              │  metrics (jsonb)                     │
                                              │  training_rows (integer)             │
                                              │  criterion (varchar)                 │
                                              │  max_depth (integer)                 │
                                              │  random_state (integer)              │
                                              │  trained_at (timestamptz)            │
                                              │  is_active (boolean)                 │
                                              │  notes (text)                        │
                                              └──────────────────────────────────────┘
```

---

## 2. Detail Tabel

### 2.1 `public.profiles`

Tabel utama pengguna, sinkron dengan `auth.users`.

| Kolom | Tipe Data | Nullable | Default | Keterangan |
|-------|-----------|----------|---------|------------|
| `id` | uuid | NOT NULL | — | PK, sama dengan `auth.users.id` |
| `full_name` | text | YES | — | Nama lengkap pengguna |
| `email` | text | YES | — | Email pengguna |
| `role` | user_role_enum | YES | — | Peran: `admin`, `guru`, `siswa` |
| `avatar_url` | text | YES | — | URL foto profil |
| `created_at` | timestamptz | NOT NULL | `now()` | Waktu dibuat |
| `updated_at` | timestamptz | NOT NULL | `now()` | Waktu diperbarui |

**Enum `user_role_enum`**: `admin` | `guru` | `siswa`

---

### 2.2 `public.detail_siswa`

Data detail dan statistik keterlambatan per siswa. Dibuat otomatis saat user dengan role `siswa` dibuat.

| Kolom | Tipe Data | Nullable | Default | Keterangan |
|-------|-----------|----------|---------|------------|
| `id` | uuid | NOT NULL | `gen_random_uuid()` | PK |
| `user_id` | uuid | YES | `gen_random_uuid()` | FK → profiles.id |
| `kelas` | varchar | YES | — | Nama kelas siswa |
| `nisn` | varchar | YES | — | Nomor Induk Siswa Nasional |
| `total_terlambat` | bigint | YES | — | Jumlah keterlambatan aktif |
| `total_menit_terlambat` | bigint | YES | — | Total menit keterlambatan aktif |
| `status_disiplin` | discipline_status_enum | NOT NULL | `'aman'` | Level disiplin saat ini |
| `created_at` | timestamptz | NOT NULL | `now()` | Waktu dibuat |
| `updated_at` | timestamptz | NOT NULL | `now()` | Waktu diperbarui |

**Enum `discipline_status_enum`**: `aman` | `ringan` | `sedang` | `berat`

---

### 2.3 `public.terlambat`

Rekam jejak setiap kejadian keterlambatan siswa.

| Kolom | Tipe Data | Nullable | Default | Keterangan |
|-------|-----------|----------|---------|------------|
| `id` | uuid | NOT NULL | `gen_random_uuid()` | PK |
| `user_id` | uuid | YES | `gen_random_uuid()` | FK → profiles.id (siswa yang terlambat) |
| `evaluator_id` | uuid | YES | — | FK → profiles.id (guru yang mengevaluasi) |
| `tanggal_terlambat` | date | YES | — | Tanggal kejadian terlambat |
| `durasi_menit` | integer | YES | — | Lamanya keterlambatan dalam menit |
| `tugas_hukuman` | text | YES | — | Jenis tugas: "Tugas Ringan/Sedang/Berat" |
| `status_evaluasi` | evaluation_status_enum | NOT NULL | — | Status siklus evaluasi |
| `alasan` | text | YES | — | Alasan keterlambatan (dari siswa/guru) |
| `kelengkapan` | boolean | YES | — | Apakah tugas lengkap (dinilai guru) |
| `kesesuaian` | boolean | YES | — | Apakah tugas sesuai (dinilai guru) |
| `nilai` | integer | YES | — | Nilai tugas (0–100) |
| `hasil_validasi` | text | YES | — | Catatan validasi dari guru |
| `created_at` | timestamptz | NOT NULL | `now()` | Waktu dicatat |
| `updated_at` | timestamptz | NOT NULL | `now()` | Waktu diperbarui |

**Enum `evaluation_status_enum`**:
- `menunggu` — Keterlambatan dicatat, tugas belum dikerjakan siswa
- `mengerjakan` — Siswa sedang mengerjakan tugas
- `revisi` — Guru meminta revisi, siswa harus upload ulang
- `menunggu_nilai` — Siswa sudah upload bukti, menunggu penilaian guru
- `selesai` — Guru sudah menilai, siklus selesai
- `dibatalkan` — Keterlambatan dibatalkan (tidak dihitung ke statistik)

---

### 2.4 `public.bukti_evaluasi`

Bukti foto pengerjaan tugas yang diupload oleh siswa.

| Kolom | Tipe Data | Nullable | Default | Keterangan |
|-------|-----------|----------|---------|------------|
| `id` | bigint | NOT NULL | — | PK (auto increment) |
| `terlambat_id` | uuid | NOT NULL | `gen_random_uuid()` | FK → terlambat.id |
| `photo_path` | varchar | NOT NULL | — | Path foto di Supabase Storage |
| `created_at` | timestamptz | NOT NULL | `now()` | Waktu upload |

---

### 2.5 `public.evaluasi_tugas` *(Baru — migrasi 20260825)*

Histori setiap kejadian evaluasi tugas oleh guru. Tabel **append-only** — tidak ada UPDATE/DELETE dari client. Berfungsi sebagai dataset training Decision Tree dan audit trail.

| Kolom | Tipe Data | Nullable | Default | Keterangan |
|-------|-----------|----------|---------|------------|
| `id` | uuid | NOT NULL | `gen_random_uuid()` | PK |
| `terlambat_id` | uuid | NOT NULL | — | FK → terlambat.id (ON DELETE CASCADE) |
| `evaluator_id` | uuid | NOT NULL | — | FK → profiles.id (guru/admin yang menilai) |
| `nilai` | smallint | NOT NULL | — | Nilai tugas (0–100) |
| `kelengkapan` | boolean | NOT NULL | — | Apakah tugas lengkap |
| `kesesuaian` | boolean | NOT NULL | — | Apakah tugas sesuai instruksi |
| `keputusan_guru` | varchar(16) | NOT NULL | — | Keputusan akhir: `selesai` atau `revisi` |
| `prediksi_model` | varchar(16) | YES | — | Prediksi AI: `selesai` atau `revisi` (null jika manual) |
| `prediction_confidence` | numeric(6,5) | YES | — | Confidence prediksi AI (0.0–1.0) |
| `model_version` | varchar(64) | YES | — | FK → decision_tree_models.version |
| `decision_source` | varchar(32) | NOT NULL | `'manual'` | `manual` atau `decision_support` |
| `created_at` | timestamptz | NOT NULL | `now()` | Waktu evaluasi |

**Indexes**:
- `idx_evaluasi_tugas_terlambat` pada `(terlambat_id, created_at DESC)`
- `idx_evaluasi_tugas_evaluator` pada `(evaluator_id, created_at DESC)`
- `idx_evaluasi_tugas_target` pada `(keputusan_guru)`

---

### 2.6 `public.decision_tree_models` *(Baru — migrasi 20260825)*

Registry model Decision Tree yang aktif. Hanya satu model boleh aktif sekaligus.

| Kolom | Tipe Data | Nullable | Default | Keterangan |
|-------|-----------|----------|---------|------------|
| `version` | varchar(64) | NOT NULL | — | PK, nama versi model (misal: `dt-v1`) |
| `tree_json` | jsonb | NOT NULL | — | Representasi pohon keputusan dalam JSON |
| `feature_names` | text[] | NOT NULL | `['nilai','kelengkapan','kesesuaian']` | Nama fitur model |
| `metrics` | jsonb | NOT NULL | `{}` | Metrik performa model (akurasi, F1, dll.) |
| `training_rows` | integer | YES | — | Jumlah baris dataset training |
| `criterion` | varchar(32) | YES | — | Kriteria split: `gini` atau `entropy` |
| `max_depth` | integer | YES | — | Kedalaman maksimum pohon |
| `random_state` | integer | YES | — | Random seed untuk reproducibility |
| `trained_at` | timestamptz | NOT NULL | `now()` | Waktu model dilatih |
| `is_active` | boolean | NOT NULL | `false` | Apakah model ini yang aktif |
| `notes` | text | YES | — | Catatan tambahan |

**Constraint**: `uq_decision_tree_one_active` — partial unique index yang menjamin hanya satu baris dengan `is_active = true`.

**Struktur `tree_json`**:
```json
{
  "version": "dt-v1",
  "features": ["nilai", "kelengkapan", "kesesuaian"],
  "classes": ["revisi", "selesai"],
  "criterion": "gini",
  "max_depth": 3,
  "random_state": 42,
  "root": {
    "type": "node",
    "feature": "nilai",
    "threshold": 75.5,
    "samples": 120,
    "left": { "type": "leaf", "class": "revisi", "confidence": 0.85, ... },
    "right": { "type": "node", ... }
  }
}
```

---

## 3. Views

### `public.v_dataset_decision_tree`

View anonim untuk ekspor dataset training. Tidak memuat informasi identitas (user_id, nama, NISN, email, photo_path).

| Kolom | Sumber | Keterangan |
|-------|--------|------------|
| `evaluation_id` | `evaluasi_tugas.id` | ID evaluasi |
| `nilai` | `evaluasi_tugas.nilai` | Nilai tugas |
| `kelengkapan` | `evaluasi_tugas.kelengkapan` | 1 = lengkap, 0 = tidak |
| `kesesuaian` | `evaluasi_tugas.kesesuaian` | 1 = sesuai, 0 = tidak |
| `target` | `evaluasi_tugas.keputusan_guru` | Label: `selesai` / `revisi` |
| `decision_source` | `evaluasi_tugas.decision_source` | `manual` / `decision_support` |
| `model_version` | `evaluasi_tugas.model_version` | Versi model yang digunakan |
| `created_at` | `evaluasi_tugas.created_at` | Waktu evaluasi |

---

## 4. Foreign Key Constraints

| Tabel (source) | Kolom | Tabel Target | Kolom Target |
|----------------|-------|--------------|--------------|
| `detail_siswa` | `user_id` | `profiles` | `id` |
| `terlambat` | `user_id` | `profiles` | `id` |
| `terlambat` | `evaluator_id` | `profiles` | `id` |
| `bukti_evaluasi` | `terlambat_id` | `terlambat` | `id` |
| `evaluasi_tugas` | `terlambat_id` | `terlambat` | `id` (ON DELETE CASCADE) |
| `evaluasi_tugas` | `evaluator_id` | `profiles` | `id` |
| `evaluasi_tugas` | `model_version` | `decision_tree_models` | `version` |

---

## 5. Database Triggers

### 5.1 `on_profile_created_siswa` (tabel: `profiles`, event: INSERT)

**Fungsi**: `handle_new_siswa_profile()`

Dipicu setiap kali ada row baru di `profiles`. Jika role user adalah `'siswa'`, otomatis membuat baris di `detail_siswa`:

```sql
BEGIN
  IF NEW.role = 'siswa'::public.user_role_enum THEN
    INSERT INTO public.detail_siswa (user_id, total_terlambat, total_menit_terlambat, status_disiplin)
    VALUES (NEW.id, 0, 0, 'aman'::public.discipline_status_enum)
    ON CONFLICT (user_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
```

---

### 5.2 `trg_update_siswa_tardiness` (tabel: `terlambat`, event: INSERT / UPDATE / DELETE)

**Fungsi**: `fn_update_tardiness()`

Dipicu setiap ada perubahan di tabel `terlambat`. Menghitung ulang statistik siswa dan memperbarui `detail_siswa`:

```sql
DECLARE
    target_user_id UUID;
    v_total_terlambat BIGINT;
    v_total_menit BIGINT;
BEGIN
    target_user_id := COALESCE(NEW.user_id, OLD.user_id);

    -- Hitung HANYA data yang belum selesai / tidak dibatalkan
    SELECT COUNT(*), COALESCE(SUM(durasi_menit), 0)
    INTO v_total_terlambat, v_total_menit
    FROM terlambat
    WHERE user_id = target_user_id
      AND status_evaluasi NOT IN ('selesai', 'dibatalkan');

    -- Update statistik dan level disiplin
    UPDATE detail_siswa
    SET
        total_terlambat = v_total_terlambat,
        total_menit_terlambat = v_total_menit,
        status_disiplin =
            CASE
                WHEN v_total_terlambat <= 2 THEN 'aman'::discipline_status_enum
                WHEN v_total_terlambat <= 4 THEN 'ringan'::discipline_status_enum
                WHEN v_total_terlambat <= 6 THEN 'sedang'::discipline_status_enum
                ELSE 'berat'::discipline_status_enum
            END
    WHERE user_id = target_user_id;

    RETURN NULL; -- AFTER TRIGGER
END;
```

---

## 6. Database Functions

| Nama Fungsi | Tipe | Deskripsi |
|-------------|------|-----------|
| `fn_update_tardiness()` | TRIGGER FUNCTION | Hitung ulang statistik keterlambatan siswa |
| `handle_new_siswa_profile()` | TRIGGER FUNCTION | Auto-create detail_siswa untuk siswa baru |
| `handle_new_user()` | TRIGGER FUNCTION | Auto-insert ke profiles dari auth.users |
| `is_admin()` | SECURITY FUNCTION | Cek apakah user saat ini adalah admin |
| `is_guru()` | SECURITY FUNCTION | Cek apakah user saat ini adalah guru |
| `record_task_evaluation(...)` | SECURITY DEFINER | *(Baru)* Simpan histori evaluasi + update terlambat dalam satu transaksi |
| `update_siswa_tardiness()` | FUNCTION | Versi lama update statistik (tidak aktif sebagai trigger) |
| `handle_evaluation_status()` | FUNCTION | Fungsi lama manajemen evaluasi (tidak aktif) |

### Fungsi Helper RLS

```sql
-- Cek apakah user yang sedang login adalah admin
CREATE FUNCTION is_admin() RETURNS boolean AS $$
  SELECT COALESCE(
    (SELECT role = 'admin' FROM public.profiles WHERE id = auth.uid()),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- Cek apakah user yang sedang login adalah guru
CREATE FUNCTION is_guru() RETURNS boolean AS $$
  SELECT COALESCE(
    (SELECT role = 'guru' FROM public.profiles WHERE id = auth.uid()),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER;
```

### Fungsi Transaksi Evaluasi (Baru)

```sql
-- Dipanggil oleh Edge Function submit-evaluation via service role
CREATE FUNCTION public.record_task_evaluation(
  p_terlambat_id uuid,
  p_evaluator_id uuid,
  p_nilai smallint,
  p_kelengkapan boolean,
  p_kesesuaian boolean,
  p_keputusan_guru varchar,
  p_prediksi_model varchar DEFAULT null,
  p_prediction_confidence numeric DEFAULT null,
  p_model_version varchar DEFAULT null,
  p_decision_source varchar DEFAULT 'manual'
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER;
-- Returns: id dari baris evaluasi_tugas yang baru dibuat
-- Hak akses: hanya service_role (Edge Function)
```

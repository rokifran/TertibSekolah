# ⚙️ Cara Kerja Sistem — Tertib Sekolah

## 1. Proses Bisnis Utama

Sistem Tertib Sekolah mengelola **siklus keterlambatan siswa** dari pencatatan hingga evaluasi tugas:

```
[Siswa Terlambat]
      │
      ▼
[Guru Input Keterlambatan]
      │  (tugas_hukuman otomatis berdasar durasi)
      ▼
[Siswa Terima Notifikasi / Lihat di Dashboard]
      │  (status: "menunggu" → siswa belum mengerjakan)
      ▼
[Siswa Upload Bukti Tugas]
      │  (foto bukti diunggah ke Supabase Storage)
      ▼
[Status berubah: "menunggu_nilai"]
      │
      ▼
[Guru Evaluasi & Beri Nilai]
      │  (kelengkapan, kesesuaian, nilai 0–100)
      │  (bisa "revisi" jika tidak sesuai)
      ▼
[Status berubah: "selesai"]
      │
      ▼
[Statistik Siswa Diperbarui Otomatis oleh Trigger DB]
```

---

## 2. Alur Autentikasi

### Login Flow

```
User input email + password
         │
         ▼
AuthService.signIn()
         │
         ├─► Supabase Auth: signInWithPassword()
         │         │
         │         ├── Berhasil → dapatkan user.id
         │         └── Gagal → throw AuthException
         │
         ├─► Query profiles WHERE id = user.id
         │         │
         │         ├── Ada → ambil full_name & role
         │         └── Tidak ada → signOut() + throw AuthException
         │
         ▼
   AuthResult { userId, nama, email, roleName }
         │
         ▼
  LoginScreen routing berdasarkan roleName:
    ┌─── 'Admin' → AdminDashboardScreen
    ├─── 'Guru'  → GuruDashboardScreen
    └─── 'Siswa' → SiswaDashboardScreen
```

### Session Management

- Session JWT disimpan oleh `supabase_flutter` (otomatis)
- Tidak ada pemeriksaan session saat startup (langsung ke LoginScreen setiap buka app)
- Logout: `AuthService.signOut()` → `supabase.auth.signOut()` → kembali ke LoginScreen

---

## 3. Workflow Per Aktor

### 👑 Admin

**Dashboard Admin** menyediakan:
- **Statistik ringkasan**: Total siswa, total keterlambatan, breakdown status
- **Manajemen User**: Tambah/hapus user (Guru, Siswa, Admin baru)
- **Evaluasi Tugas**: Bisa ikut mengevaluasi tugas seperti Guru

**Menambah User Baru**:
```
Admin klik "Tambah User"
         │
         ▼
_AddUserSheet (BottomSheet)
  ├─ Input: nama, email, password, role
         │
         ▼
POST /functions/v1/create-user (Edge Function)
  ├─ Verifikasi token admin
  ├─ supabaseClient.auth.admin.createUser(...)
  ├─ INSERT into profiles (id, email, full_name, role)
  └─ Jika role 'siswa': INSERT into detail_siswa (...)
         │
         ▼
Trigger DB: on_profile_created_siswa
  └─ Otomatis buat baris detail_siswa jika role = 'siswa'
```

**Menghapus User**:
```
Admin konfirmasi hapus
         │
         ▼
POST /functions/v1/delete-user (Edge Function)
  ├─ Verifikasi token admin
  ├─ DELETE from detail_siswa WHERE user_id = userId
  ├─ DELETE from profiles WHERE id = userId
  └─ supabaseClient.auth.admin.deleteUser(userId)
```

---

### 👨‍🏫 Guru

**Dashboard Guru** memiliki 3 tab:

#### Tab 1: Beranda (Home)
- Salam + tanggal hari ini
- **Bento Grid** 3 quick-action:
  - Input Keterlambatan (primary card)
  - Evaluasi Tugas (dengan counter tugas pending)
  - Data Siswa (dengan counter level risiko)
- **Aktivitas Terkini**: Feed 10 record terlambat terbaru

#### Tab 2: Evaluasi Tugas
Daftar keterlambatan dikelompokkan menjadi 3 kategori:
- **Perlu Tugas**: Status `menunggu` → guru belum assign tugas (auto-assign via form input)
- **Menunggu Bukti**: Status `mengerjakan` atau `revisi` → siswa sedang mengerjakan
- **Perlu Dinilai**: Status `menunggu_nilai` → siswa sudah upload bukti

#### Tab 3: Data Siswa
- Daftar semua siswa dengan status disiplin
- Bisa melihat detail per siswa

**Input Keterlambatan**:
```
Form InputKeterlambatanScreen:
  ├─ Cari nama siswa (autocomplete dari tabel detail_siswa + profiles)
  ├─ Pilih tanggal (date picker)
  ├─ Input durasi keterlambatan (menit)
  └─ Input alasan (opsional)
         │
         ▼
Auto-assign tugas_hukuman berdasar durasi:
  ├─ ≤15 menit → "Tugas Ringan"
  ├─ 16-30 menit → "Tugas Sedang"
  └─ >30 menit → "Tugas Berat"
         │
         ▼
INSERT into terlambat (user_id, tanggal, durasi, tugas_hukuman, status='menunggu')
         │
         ▼
DB Trigger: trg_update_siswa_tardiness
  └─ Hitung ulang total_terlambat & status_disiplin di detail_siswa
```

**Evaluasi / Penilaian Tugas**:
```
FormEvaluasiTugasScreen:
  ├─ Lihat foto bukti tugas (dari bukti_evaluasi)
  ├─ Input nilai (0-100)
  ├─ Centang kelengkapan & kesesuaian
  └─ Hasil validasi (teks)
         │
         ▼
UPDATE terlambat SET status='selesai', nilai=..., kelengkapan=..., kesesuaian=...
  └─ ATAU status='revisi' jika tugas tidak sesuai
```

---

### 🎒 Siswa

**Dashboard Siswa** memiliki 2 tab:

#### Tab 1: Beranda
- Info nama, kelas, dan level disiplin saat ini
- Statistik total keterlambatan
- Level risiko: `Aman` → `Ringan` → `Sedang` → `Berat`
- Daftar tugas keterlambatan beserta statusnya

#### Tab 2: Riwayat
- History lengkap keterlambatan

**Upload Bukti Tugas**:
```
Siswa tap kartu tugas berstatus 'mengerjakan'
         │
         ▼
Pilih foto dari kamera/galeri (image_picker)
         │
         ▼
Kompresi foto (flutter_image_compress)
         │
         ▼
Upload ke Supabase Storage
         │
         ▼
INSERT into bukti_evaluasi (terlambat_id, photo_path)
         │
         ▼
UPDATE terlambat SET status='menunggu_nilai'
```

---

## 4. Sistem Level Disiplin Siswa

Level disiplin dihitung berdasarkan jumlah keterlambatan **aktif** (bukan yang `selesai` atau `dibatalkan`):

```
Total Keterlambatan Aktif:
  ├─ 0–2 kali → Status: "aman"   (hijau)
  ├─ 3–4 kali → Status: "ringan" (kuning/hijau muda)
  ├─ 5–6 kali → Status: "sedang" (oranye)
  └─ >6 kali  → Status: "berat"  (merah)
```

**Kalkulasi otomatis** dilakukan oleh:
1. **DB Trigger** `trg_update_siswa_tardiness` setiap ada INSERT/UPDATE/DELETE di tabel `terlambat`
2. **Frontend** (GuruDashboardScreen) juga memvalidasi dan sync ulang saat load data

---

## 5. Siklus Status Keterlambatan

```
[menunggu]
    │ Guru assign tugas (otomatis saat input)
    ▼
[mengerjakan]  ←───────────────────────────────┐
    │ Siswa upload bukti                        │
    ▼                                           │
[menunggu_nilai]                              [revisi]
    │ Guru menilai                              │
    ├──────────────────────────────────────────►┘  (jika revisi)
    │ Guru setujui
    ▼
 [selesai]

[dibatalkan]  ← Bisa dari status apapun (oleh Admin/Guru)
```

---

## 6. Realtime Updates

Kedua dashboard (Guru dan Siswa) menggunakan **Supabase Realtime** untuk mendapatkan update otomatis:

```dart
// Contoh setup realtime di GuruDashboardScreen
supabase
  .channel('public:dashboard:guru')
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'terlambat',
    callback: (payload) {
      if (mounted) _fetchDashboardData();
    })
  .subscribe();
```

Setiap ada perubahan di tabel `terlambat` atau `detail_siswa`, dashboard akan **otomatis refresh** tanpa perlu pull-to-refresh manual.

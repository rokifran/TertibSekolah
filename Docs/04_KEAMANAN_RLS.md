# 🔒 Keamanan & Row-Level Security (RLS) — Tertib Sekolah

## 1. Gambaran Umum Keamanan

Tertib Sekolah menggunakan **Row-Level Security (RLS)** PostgreSQL yang diaktifkan di semua tabel publik. RLS memastikan setiap pengguna hanya bisa mengakses data yang sesuai dengan perannya.

**Semua tabel memiliki RLS diaktifkan (`rls_enabled: true`)**:
- `profiles`
- `detail_siswa`
- `terlambat`
- `bukti_evaluasi`

---

## 2. Prinsip Keamanan

| Prinsip | Implementasi |
|---------|-------------|
| **Principle of Least Privilege** | Setiap role hanya mendapat akses minimum yang dibutuhkan |
| **RLS Server-side** | Kontrol akses dilakukan di level database, bukan hanya di frontend |
| **JWT-based Auth** | Setiap request menggunakan token JWT dari Supabase Auth |
| **Service Role untuk Admin Ops** | Operasi admin (create/delete user) hanya via Edge Function dengan service role key |
| **Env Vars Injection** | Credentials tidak di-hardcode, di-inject via `dart-define-from-file` |

---

## 3. Policies per Tabel

### 3.1 Tabel `profiles`

| Policy Name | Command | Role | Kondisi |
|-------------|---------|------|---------|
| Users can view own profile | SELECT | public | `auth.uid() = id` |
| Users can insert own profile | INSERT | public | — (check otomatis) |
| Users can update own profile | UPDATE | public | `auth.uid() = id` |
| Enable read access for authenticated users | SELECT | authenticated | `true` (semua authenticated) |
| Admins can view all profiles | SELECT | public | `is_admin()` |
| Admins can update all profiles | UPDATE | public | `is_admin()` |
| Admins can delete all profiles | DELETE | public | `is_admin()` |

**Kesimpulan akses `profiles`**:
- Siswa/Guru: bisa baca profile sendiri + baca profile siapapun (karena `authenticated` read)
- Admin: full CRUD semua profile

---

### 3.2 Tabel `detail_siswa`

| Policy Name | Command | Role | Kondisi |
|-------------|---------|------|---------|
| Siswa can view own detail_siswa | SELECT | public | `auth.uid() = user_id` |
| Guru can view all detail_siswa | SELECT | public | `is_guru()` |
| Admins can do everything on detail_siswa | ALL | public | `is_admin()` |

**Kesimpulan akses `detail_siswa`**:
- Siswa: hanya bisa baca data diri sendiri
- Guru: bisa baca data semua siswa (tidak bisa edit)
- Admin: full CRUD semua data

---

### 3.3 Tabel `terlambat`

| Policy Name | Command | Role | Kondisi |
|-------------|---------|------|---------|
| Siswa can view own terlambat | SELECT | public | `auth.uid() = user_id` |
| Siswa can update own terlambat | UPDATE | public | `auth.uid() = user_id` |
| Guru can view all terlambat | SELECT | public | `is_guru()` |
| Guru can insert terlambat | INSERT | public | — (guru bisa insert) |
| Guru can update all terlambat | UPDATE | public | `is_guru()` |
| Admins can view all terlambat | SELECT | public | `is_admin()` |
| Admins can insert terlambat | INSERT | public | — |
| Admins can update all terlambat | UPDATE | public | `is_admin()` |
| Admins can delete terlambat | DELETE | public | `is_admin()` |

**Kesimpulan akses `terlambat`**:
- Siswa: baca data keterlambatan sendiri, bisa update (untuk upload bukti/status)
- Guru: baca semua data, insert data baru, update semua data (untuk evaluasi)
- Admin: full CRUD

---

### 3.4 Tabel `bukti_evaluasi`

| Policy Name | Command | Role | Kondisi |
|-------------|---------|------|---------|
| Siswa can view own bukti_evaluasi | SELECT | public | EXISTS(SELECT 1 FROM terlambat t WHERE t.id = bukti_evaluasi.terlambat_id AND t.user_id = auth.uid()) |
| Siswa can insert own bukti_evaluasi | INSERT | public | — |
| Guru can view all bukti_evaluasi | SELECT | public | `is_guru()` |
| Guru can insert bukti_evaluasi | INSERT | public | — |
| Guru can update all bukti_evaluasi | UPDATE | public | `is_guru()` |
| Admins can view all bukti_evaluasi | SELECT | public | `is_admin()` |
| Admins can insert bukti_evaluasi | INSERT | public | — |
| Admins can update all bukti_evaluasi | UPDATE | public | `is_admin()` |
| Admins can delete bukti_evaluasi | DELETE | public | `is_admin()` |

**Kesimpulan akses `bukti_evaluasi`**:
- Siswa: baca & insert bukti milik sendiri (diverifikasi via join ke tabel terlambat)
- Guru: baca, insert, dan update semua bukti
- Admin: full CRUD

---

## 4. Matrix Akses Ringkas

| Operasi | Admin | Guru | Siswa |
|---------|-------|------|-------|
| **profiles** | | | |
| Baca semua profile | ✅ | ✅* | ✅* |
| Edit profile sendiri | ✅ | ✅ | ✅ |
| Edit semua profile | ✅ | ❌ | ❌ |
| Hapus profile | ✅ | ❌ | ❌ |
| **detail_siswa** | | | |
| Baca data sendiri | ✅ | N/A | ✅ |
| Baca semua data | ✅ | ✅ | ❌ |
| Edit data | ✅ | ❌** | ❌ |
| **terlambat** | | | |
| Baca keterlambatan sendiri | ✅ | N/A | ✅ |
| Baca semua keterlambatan | ✅ | ✅ | ❌ |
| Input keterlambatan | ✅ | ✅ | ❌ |
| Update (evaluasi) | ✅ | ✅ | ✅*** |
| Hapus | ✅ | ❌ | ❌ |
| **bukti_evaluasi** | | | |
| Baca bukti sendiri | ✅ | N/A | ✅ |
| Baca semua bukti | ✅ | ✅ | ❌ |
| Upload bukti | ✅ | ✅ | ✅ |
| Hapus bukti | ✅ | ❌ | ❌ |

> *Karena ada policy `authenticated` read di profiles  
> **Guru bisa update detail_siswa via trigger DB (bukan langsung)  
> ***Siswa hanya bisa update data keterlambatan milik sendiri (untuk update status/upload bukti)

---

## 5. Keamanan Edge Functions

Kedua Edge Function mengimplementasikan **double verification**:

1. **Verifikasi Token JWT**: Setiap request harus membawa `Authorization: Bearer <token>`
2. **Verifikasi Role Admin**: Query ke tabel `profiles` untuk memastikan caller memiliki role `admin`

```typescript
// Contoh dari create-user/index.ts
const token = authHeader.replace('Bearer ', '');
const { data: { user } } = await supabaseClient.auth.getUser(token);

const { data: userData } = await supabaseClient
  .from('profiles')
  .select('role')
  .eq('id', user.id)
  .single();

if (userData.role !== 'admin') {
  throw new Error('Forbidden: Only admin can create users');
}
```

---

## 6. Keamanan Konfigurasi

### Environment Variables
- Credentials Supabase **tidak pernah di-hardcode** dalam source code
- File `.env` di-ignore oleh Git (tercantum dalam `.gitignore`)
- Disediakan `.env.example` sebagai panduan setup

### Konfigurasi Client
- Flutter menggunakan **Anon Key** (public key) — sudah dibatasi oleh RLS
- Edge Functions menggunakan **Service Role Key** — hanya di server, tidak di client

### Validasi di `SupabaseConfig`
```dart
static void validate() {
  final List<String> missing = [];
  if (url.isEmpty) missing.add('SUPABASE_URL');
  if (anonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
  if (missing.isNotEmpty) throw Exception('Env vars tidak dikonfigurasi: ...');
}
```

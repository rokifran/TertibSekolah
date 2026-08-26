# 🔒 Keamanan & Row-Level Security (RLS) — Tertib Sekolah

## 1. Gambaran Umum Keamanan

Tertib Sekolah menggunakan **Row-Level Security (RLS)** PostgreSQL yang diaktifkan di semua tabel publik. RLS memastikan setiap pengguna hanya bisa mengakses data yang sesuai dengan perannya.

**Semua tabel memiliki RLS diaktifkan (`rls_enabled: true`)**:
- `profiles`
- `detail_siswa`
- `terlambat`
- `bukti_evaluasi`
- `evaluasi_tugas` *(Baru)*
- `decision_tree_models` *(Baru)*

---

## 2. Prinsip Keamanan

| Prinsip | Implementasi |
|---------|-------------|
| **Principle of Least Privilege** | Setiap role hanya mendapat akses minimum yang dibutuhkan |
| **RLS Server-side** | Kontrol akses dilakukan di level database, bukan hanya di frontend |
| **JWT-based Auth** | Setiap request menggunakan token JWT dari Supabase Auth |
| **Service Role untuk Admin Ops** | Operasi admin (create/delete user) dan evaluasi ML hanya via Edge Function dengan service role key |
| **Env Vars Injection** | Credentials tidak di-hardcode, di-inject via `dart-define-from-file` |
| **Fungsi SECURITY DEFINER** | `record_task_evaluation` berjalan dengan hak service_role; hak execute dicabut dari public/anon/authenticated |

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

> **Catatan**: Update status evaluasi (`selesai`/`revisi`) dilakukan oleh Edge Function `submit-evaluation` menggunakan service role via fungsi `record_task_evaluation`, bukan langsung dari client.

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

### 3.5 Tabel `evaluasi_tugas` *(Baru)*

| Policy Name | Command | Role | Kondisi |
|-------------|---------|------|---------|
| `evaluasi_tugas_select_authorized` | SELECT | authenticated | Guru/Admin: peran di profiles; Siswa: via join ke terlambat.user_id |

**Kesimpulan akses `evaluasi_tugas`**:
- **SELECT**: Guru & Admin bisa baca semua; Siswa hanya bisa baca histori milik sendiri
- **INSERT/UPDATE/DELETE**: **Tidak ada policy client** — penulisan dilakukan secara eksklusif oleh Edge Function `submit-evaluation` menggunakan service role (melewati RLS)

Policy SELECT:
```sql
CREATE POLICY evaluasi_tugas_select_authorized
ON public.evaluasi_tugas FOR SELECT TO authenticated
USING (
  -- Guru atau admin
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role IN ('guru', 'admin')
  )
  -- Atau siswa yang bersangkutan
  OR EXISTS (
    SELECT 1 FROM public.terlambat t
    WHERE t.id = evaluasi_tugas.terlambat_id
      AND t.user_id = auth.uid()
  )
);
```

---

### 3.6 Tabel `decision_tree_models` *(Baru)*

| Policy | Keterangan |
|--------|------------|
| Tidak ada policy SELECT untuk client | Edge Function membaca model menggunakan service role |
| Tidak ada policy INSERT/UPDATE/DELETE | Manajemen model dilakukan via Supabase Dashboard / SQL langsung oleh developer |

**Kesimpulan**: Model Decision Tree **tidak pernah terekspos langsung** ke Flutter client. `tree_json` hanya bisa diakses oleh Edge Function dengan service role.

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
| Update (evaluasi) | ✅ | ✅*** | ✅**** |
| Hapus | ✅ | ❌ | ❌ |
| **bukti_evaluasi** | | | |
| Baca bukti sendiri | ✅ | N/A | ✅ |
| Baca semua bukti | ✅ | ✅ | ❌ |
| Upload bukti | ✅ | ✅ | ✅ |
| Hapus bukti | ✅ | ❌ | ❌ |
| **evaluasi_tugas** | | | |
| Baca histori evaluasi | ✅ | ✅ | ✅***** |
| Tulis evaluasi | Edge Fn | Edge Fn | ❌ |
| **decision_tree_models** | | | |
| Akses model | Edge Fn | ❌ | ❌ |

> \* Karena ada policy `authenticated` read di profiles  
> \*\* Guru bisa update detail_siswa via trigger DB (bukan langsung)  
> \*\*\* Guru mengevaluasi via Edge Function `submit-evaluation` (service role)  
> \*\*\*\* Siswa hanya bisa update data keterlambatan milik sendiri (upload bukti/status)  
> \*\*\*\*\* Siswa hanya bisa baca histori evaluasi milik sendiri

---

## 5. Keamanan Edge Functions

### `create-user` dan `delete-user`

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

### `predict-evaluation`

- **Tidak memerlukan autentikasi** untuk membaca model (model tidak memuat data pribadi)
- Menggunakan service role secara internal untuk membaca `decision_tree_models`
- Input: `nilai`, `kelengkapan`, `kesesuaian` — tidak ada data identitas

### `submit-evaluation`

- **Memerlukan JWT Guru atau Admin**: Verifikasi token + cek role dari `profiles`
- Siswa **tidak bisa** memanggil fungsi ini
- Setelah verifikasi, memanggil `record_task_evaluation` via service role (melewati RLS)

```typescript
const role: string = profile.role;
if (role !== 'guru' && role !== 'admin') {
  return new Response(
    JSON.stringify({ error: 'Hanya guru atau admin yang dapat menyimpan evaluasi' }),
    { status: 403, ... },
  );
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

### Keamanan Model ML
- `tree_json` di tabel `decision_tree_models` **tidak bisa diakses** oleh Flutter client (tidak ada policy SELECT untuk authenticated)
- Edge Function `predict-evaluation` tidak mengembalikan struktur pohon — hanya hasil prediksi (label + confidence)
- Dataset training diekspor via view anonim `v_dataset_decision_tree` tanpa data pribadi

# ⚡ Supabase Edge Functions — Tertib Sekolah

Edge Functions adalah serverless functions yang berjalan di Deno runtime, digunakan untuk operasi yang memerlukan **service role privileges** (tidak bisa dilakukan dari client langsung).

---

## 1. `create-user`

**Path**: `supabase/functions/create-user/index.ts`  
**Endpoint**: `POST /functions/v1/create-user`  
**Deskripsi**: Membuat user baru dengan role tertentu (admin, guru, siswa). Hanya bisa dipanggil oleh Admin.

### Request Headers
```
Authorization: Bearer <admin-jwt-token>
Content-Type: application/json
```

### Request Body
```json
{
  "email": "user@example.com",
  "password": "password123",
  "nama": "Nama Lengkap User",
  "role": "siswa"  // "admin" | "guru" | "siswa"
}
```

### Success Response (200)
```json
{
  "message": "User created successfully",
  "user": { ...supabase_user_object }
}
```

### Error Response (400)
```json
{
  "error": {
    "message": "Forbidden: Only admin can create users",
    "name": "Error"
  }
}
```

### Alur Eksekusi

```
Request masuk
      │
      ├─ Verifikasi Authorization header
      ├─ getUser(token) → validasi JWT
      ├─ Query profiles.role = 'admin' → verifikasi peran
      │
      ├─ Validasi fields: email, password, nama, role
      ├─ Validasi role: harus 'admin' | 'guru' | 'siswa'
      │
      ├─ auth.admin.createUser({ email, password, email_confirm: true })
      ├─ profiles.upsert({ id, email, full_name, role })
      │
      └─ Jika role = 'siswa':
           └─ detail_siswa.upsert({ user_id, total_terlambat:0, ... })
                  │
                  └─ (trigger on_profile_created_siswa juga berjalan otomatis)
```

### Rollback Strategy

Jika langkah intermediate gagal:
- Jika `profiles.upsert` gagal → `auth.admin.deleteUser()` untuk cleanup
- Jika `detail_siswa.upsert` gagal → hapus dari `profiles` dan `auth`

---

## 2. `delete-user`

**Path**: `supabase/functions/delete-user/index.ts`  
**Endpoint**: `POST /functions/v1/delete-user`  
**Deskripsi**: Menghapus user beserta semua data terkait. Hanya bisa dipanggil oleh Admin.

### Request Headers
```
Authorization: Bearer <admin-jwt-token>
Content-Type: application/json
```

### Request Body
```json
{
  "userId": "uuid-of-user-to-delete"
}
```

### Success Response (200)
```json
{
  "message": "User and Auth account deleted successfully"
}
```

### Error Response (400)
```json
{
  "error": {
    "message": "Tidak dapat menghapus akun admin yang sedang digunakan"
  }
}
```

### Alur Eksekusi

```
Request masuk
      │
      ├─ Verifikasi Authorization header
      ├─ getUser(token) → validasi JWT
      ├─ Query profiles.role = 'admin' → verifikasi peran
      │
      ├─ Proteksi: userId !== user.id (tidak bisa hapus diri sendiri)
      │
      ├─ 1. detail_siswa.delete({ user_id: userId })
      ├─ 2. profiles.delete({ id: userId })
      └─ 3. auth.admin.deleteUser(userId)
```

### Urutan Hapus

Penghapusan dilakukan secara berurutan untuk menjaga integritas referensial:
1. `detail_siswa` (child dari profiles)
2. `profiles` (child dari auth.users)
3. `auth.users` (via Admin API)

> **Catatan**: Data di tabel `terlambat` yang memiliki `user_id` yang dihapus belum ditangani cleanup-nya secara eksplisit di edge function ini.

---

## 3. Cara Deploy Edge Functions

```bash
# Deploy semua functions
supabase functions deploy

# Deploy function tertentu
supabase functions deploy create-user
supabase functions deploy delete-user
```

## 4. Environment Variables di Edge Functions

Edge Functions secara otomatis mendapat akses ke:
- `SUPABASE_URL` — URL project Supabase
- `SUPABASE_SERVICE_ROLE_KEY` — Service role key (full admin access, tidak terbatas RLS)

Tidak perlu konfigurasi manual — sudah di-inject oleh platform Supabase.

## 5. CORS Configuration

Kedua Edge Functions mengizinkan CORS dari semua origin (`*`) karena dipanggil dari client Flutter:

```typescript
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Handle preflight request
if (req.method === 'OPTIONS') {
  return new Response('ok', { headers: corsHeaders });
}
```

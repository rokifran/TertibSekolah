# ⚡ Supabase Edge Functions — Tertib Sekolah

Edge Functions adalah serverless functions yang berjalan di Deno runtime, digunakan untuk operasi yang memerlukan **service role privileges** (tidak bisa dilakukan dari client langsung).

Saat ini terdapat **4 Edge Functions**:

| Function | Endpoint | Siapa yang Memanggil | Kegunaan |
|----------|----------|----------------------|----------|
| `create-user` | `POST /functions/v1/create-user` | Admin only | Buat user baru |
| `delete-user` | `POST /functions/v1/delete-user` | Admin only | Hapus user |
| `predict-evaluation` | `POST /functions/v1/predict-evaluation` | Guru / Admin | Prediksi Decision Tree |
| `submit-evaluation` | `POST /functions/v1/submit-evaluation` | Guru / Admin | Simpan histori evaluasi |

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

## 3. `predict-evaluation` *(Baru)*

**Path**: `supabase/functions/predict-evaluation/index.ts`  
**Endpoint**: `POST /functions/v1/predict-evaluation`  
**Deskripsi**: Menjalankan inferensi Decision Tree untuk memprediksi hasil evaluasi tugas. Tidak memerlukan autentikasi (input tidak memuat data pribadi). Jika belum ada model aktif, mengembalikan `{ model_active: false }`.

### Request Body
```json
{
  "nilai": 85,
  "kelengkapan": true,
  "kesesuaian": true
}
```

> `kelengkapan` dan `kesesuaian` menerima `true/false` atau `1/0`.

### Success Response — Model Aktif (200)
```json
{
  "model_active": true,
  "prediksi": "selesai",
  "confidence": 0.923077,
  "model_version": "dt-v1"
}
```

### Success Response — Model Belum Ada (200)
```json
{
  "model_active": false
}
```

### Error Response (400)
```json
{
  "error": "nilai harus angka 0-100"
}
```

### Alur Eksekusi

```
Request masuk (POST)
      │
      ├─ Parse body: nilai, kelengkapan, kesesuaian
      ├─ Validasi: nilai harus 0–100
      │
      ├─ Query decision_tree_models WHERE is_active = true
      │       ├─ Tidak ada? → return { model_active: false }
      │       └─ Ada? → load tree_json
      │
      ├─ traverseTree(root, { nilai, kelengkapan, kesesuaian })
      │       └─ Traversal rekursif hingga leaf node
      │
      └─ return { model_active: true, prediksi, confidence, model_version }
```

### Penggunaan di Flutter

```dart
// Via DecisionTreeService
final prediction = await DecisionTreeService.predict(
  nilai: 85,
  kelengkapan: true,
  kesesuaian: true,
);

if (!prediction.modelActive) {
  // Tampilkan form evaluasi manual tanpa AI
} else {
  // Tampilkan saran: prediction.prediksi + prediction.confidencePersen
}
```

---

## 4. `submit-evaluation` *(Baru)*

**Path**: `supabase/functions/submit-evaluation/index.ts`  
**Endpoint**: `POST /functions/v1/submit-evaluation`  
**Deskripsi**: Menyimpan histori evaluasi tugas dan memperbarui status terlambat dalam satu transaksi server-side. Hanya bisa dipanggil oleh Guru atau Admin.

### Request Headers
```
Authorization: Bearer <guru-or-admin-jwt-token>
Content-Type: application/json
```

### Request Body
```json
{
  "terlambat_id": "uuid",
  "nilai": 85,
  "kelengkapan": true,
  "kesesuaian": true,
  "keputusan_guru": "selesai",
  "prediksi_model": "selesai",
  "prediction_confidence": 0.923077,
  "model_version": "dt-v1",
  "decision_source": "decision_support"
}
```

> `prediksi_model`, `prediction_confidence`, dan `model_version` boleh `null` jika evaluasi manual (model tidak aktif).  
> `decision_source`: `"manual"` atau `"decision_support"`.

### Success Response (200)
```json
{
  "evaluation_id": "uuid-dari-evaluasi_tugas-yang-baru-dibuat"
}
```

### Error Responses

| Status | Kondisi |
|--------|---------|
| 401 | Tidak ada Authorization header |
| 401 | Token tidak valid |
| 403 | Profil tidak ditemukan |
| 403 | Role bukan guru atau admin |
| 400 | `terlambat_id` kosong |
| 400 | `nilai` tidak valid (bukan 0–100) |
| 400 | `keputusan_guru` bukan `selesai` atau `revisi` |
| 500 | Error internal (misal: record terlambat tidak ditemukan) |

### Alur Eksekusi

```
Request masuk (POST)
      │
      ├─ Verifikasi Authorization header
      ├─ getUser(token) → validasi JWT
      ├─ Query profiles.role → verifikasi: harus 'guru' atau 'admin'
      │
      ├─ Parse body: terlambat_id, nilai, kelengkapan, kesesuaian,
      │              keputusan_guru, prediksi_model, confidence, model_version, decision_source
      ├─ Validasi field wajib & nilai 0–100
      │
      ├─ supabaseAdmin.rpc('record_task_evaluation', {
      │       p_terlambat_id, p_evaluator_id (user.id),
      │       p_nilai, p_kelengkapan, p_kesesuaian,
      │       p_keputusan_guru, p_prediksi_model, p_prediction_confidence,
      │       p_model_version, p_decision_source
      │   })
      │       ├─ INSERT evaluasi_tugas (histori)
      │       └─ UPDATE terlambat SET status=keputusan, nilai=..., ...
      │
      └─ return { evaluation_id }
```

### Penggunaan di Flutter

```dart
// Via DecisionTreeService
final result = await DecisionTreeService.submitEvaluation(
  terlambatId: terlambatId,
  nilai: 85,
  kelengkapan: true,
  kesesuaian: true,
  keputusanGuru: 'selesai',
  prediksiModel: prediction.prediksi,            // null jika model tidak aktif
  predictionConfidence: prediction.confidence,   // null jika model tidak aktif
  modelVersion: prediction.modelVersion,         // null jika model tidak aktif
);
```

---

## 5. Cara Deploy Edge Functions

```bash
# Deploy semua functions
supabase functions deploy

# Deploy function tertentu
supabase functions deploy create-user
supabase functions deploy delete-user
supabase functions deploy predict-evaluation
supabase functions deploy submit-evaluation
```

---

## 6. Environment Variables di Edge Functions

Edge Functions secara otomatis mendapat akses ke:
- `SUPABASE_URL` — URL project Supabase
- `SUPABASE_ANON_KEY` — Anon key (digunakan oleh `submit-evaluation` untuk verifikasi JWT user)
- `SUPABASE_SERVICE_ROLE_KEY` — Service role key (full admin access, tidak terbatas RLS)

Tidak perlu konfigurasi manual — sudah di-inject oleh platform Supabase.

---

## 7. CORS Configuration

Semua Edge Functions mengizinkan CORS dari semua origin (`*`) karena dipanggil dari client Flutter:

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

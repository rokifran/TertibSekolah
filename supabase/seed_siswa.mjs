import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://gaiagxlmtancqreovmai.supabase.co';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!SERVICE_ROLE_KEY) {
  console.error('SUPABASE_SERVICE_ROLE_KEY belum diisi. Jalankan:');
  console.error('SUPABASE_SERVICE_ROLE_KEY=your_key_here node supabase/seed_siswa.mjs');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const siswa = [
  { nama: 'Adi Putra',     email: 'adi.putra@contoh.com',     kelas: 'X IPA 1',  nisn: '123456001' },
  { nama: 'Bunga Citra',   email: 'bunga.citra@contoh.com',   kelas: 'X IPA 1',  nisn: '123456002' },
  { nama: 'Cahyo Nugroho', email: 'cahyo.nugroho@contoh.com', kelas: 'X IPA 1',  nisn: '123456003' },
  { nama: 'Dewi Lestari',  email: 'dewi.lestari@contoh.com',  kelas: 'X IPA 2',  nisn: '123456004' },
  { nama: 'Eko Prasetyo',  email: 'eko.prasetyo@contoh.com',  kelas: 'X IPA 2',  nisn: '123456005' },
  { nama: 'Fitri Handayani',email: 'fitri.handayani@contoh.com',kelas: 'X IPA 2', nisn: '123456006' },
  { nama: 'Gilang Permana', email: 'gilang.permana@contoh.com',kelas: 'X IPA 3', nisn: '123456007' },
  { nama: 'Hesti Rahayu',  email: 'hesti.rahayu@contoh.com',  kelas: 'X IPA 3',  nisn: '123456008' },
  { nama: 'Indra Saputra', email: 'indra.saputra@contoh.com', kelas: 'X IPA 3',  nisn: '123456009' },
  { nama: 'Joko Widodo',   email: 'joko.widodo@contoh.com',   kelas: 'XI IPA 1', nisn: '123456010' },
];

const PASSWORD = 'siswa123';

for (const s of siswa) {
  const { data: existing } = await supabase
    .from('profiles')
    .select('id')
    .eq('email', s.email)
    .maybeSingle();

  if (existing) {
    console.log(`Skip ${s.email} (sudah ada)`);
    continue;
  }

  const { data: user, error } = await supabase.auth.admin.createUser({
    email: s.email,
    password: PASSWORD,
    email_confirm: true,
    user_metadata: { nama: s.nama, role: 'siswa' },
  });

  if (error) {
    console.error(`Gagal buat ${s.email}:`, error.message);
    continue;
  }

  const userId = user.user.id;

  await supabase.from('profiles').upsert({
    id: userId,
    email: s.email,
    full_name: s.nama,
    role: 'siswa',
  });

  await supabase.from('detail_siswa').upsert({
    user_id: userId,
    kelas: s.kelas,
    nisn: s.nisn,
    total_terlambat: 0,
    total_menit_terlambat: 0,
    status_disiplin: 'aman',
  });

  console.log(`OK ${s.email} (${s.nama})`);
}

console.log('\nSelesai!');
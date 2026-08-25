-- ============================================================
-- TertibSekolah - Decision Tree research support migration
-- Baseline: branch update-frontend / schema V2
-- Target: histori evaluasi + model registry
-- Jalankan terlebih dahulu pada project Supabase staging.
-- ============================================================

begin;

-- 1) Histori evaluasi. Tabel ini sengaja append-only dari sisi client.
create table if not exists public.evaluasi_tugas (
  id uuid primary key default gen_random_uuid(),
  terlambat_id uuid not null references public.terlambat(id) on delete cascade,
  evaluator_id uuid not null references public.profiles(id),
  nilai smallint not null check (nilai between 0 and 100),
  kelengkapan boolean not null,
  kesesuaian boolean not null,
  keputusan_guru varchar(16) not null
    check (keputusan_guru in ('selesai', 'revisi')),
  prediksi_model varchar(16)
    check (prediksi_model is null or prediksi_model in ('selesai', 'revisi')),
  prediction_confidence numeric(6,5)
    check (prediction_confidence is null or prediction_confidence between 0 and 1),
  model_version varchar(64),
  decision_source varchar(32) not null default 'manual'
    check (decision_source in ('manual', 'decision_support')),
  created_at timestamptz not null default now()
);

create index if not exists idx_evaluasi_tugas_terlambat
  on public.evaluasi_tugas(terlambat_id, created_at desc);

create index if not exists idx_evaluasi_tugas_evaluator
  on public.evaluasi_tugas(evaluator_id, created_at desc);

create index if not exists idx_evaluasi_tugas_target
  on public.evaluasi_tugas(keputusan_guru);

-- 2) Registry model. tree_json dihasilkan oleh 04_ml/train_decision_tree.py.
create table if not exists public.decision_tree_models (
  version varchar(64) primary key,
  tree_json jsonb not null,
  feature_names text[] not null default array['nilai','kelengkapan','kesesuaian'],
  metrics jsonb not null default '{}'::jsonb,
  training_rows integer,
  criterion varchar(32),
  max_depth integer,
  random_state integer,
  trained_at timestamptz not null default now(),
  is_active boolean not null default false,
  notes text
);

-- Hanya satu model boleh aktif. Partial unique index menjamin hal ini.
create unique index if not exists uq_decision_tree_one_active
  on public.decision_tree_models ((is_active))
  where is_active = true;

-- FK model_version dibuat setelah tabel registry tersedia.
do $$
begin
  if not exists (
    select 1
    from information_schema.table_constraints
    where table_schema = 'public'
      and table_name = 'evaluasi_tugas'
      and constraint_name = 'evaluasi_tugas_model_version_fkey'
  ) then
    alter table public.evaluasi_tugas
      add constraint evaluasi_tugas_model_version_fkey
      foreign key (model_version)
      references public.decision_tree_models(version);
  end if;
end $$;

-- 3) Fungsi transaksi server-side untuk menyimpan histori + snapshot terkini.
create or replace function public.record_task_evaluation(
  p_terlambat_id uuid,
  p_evaluator_id uuid,
  p_nilai smallint,
  p_kelengkapan boolean,
  p_kesesuaian boolean,
  p_keputusan_guru varchar,
  p_prediksi_model varchar default null,
  p_prediction_confidence numeric default null,
  p_model_version varchar default null,
  p_decision_source varchar default 'manual'
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if p_nilai < 0 or p_nilai > 100 then
    raise exception 'nilai harus 0-100';
  end if;
  if p_keputusan_guru not in ('selesai','revisi') then
    raise exception 'keputusan_guru tidak valid';
  end if;

  insert into public.evaluasi_tugas(
    terlambat_id, evaluator_id, nilai, kelengkapan, kesesuaian,
    keputusan_guru, prediksi_model, prediction_confidence, model_version,
    decision_source
  ) values (
    p_terlambat_id, p_evaluator_id, p_nilai, p_kelengkapan, p_kesesuaian,
    p_keputusan_guru, p_prediksi_model, p_prediction_confidence, p_model_version,
    p_decision_source
  ) returning id into v_id;

  update public.terlambat
  set nilai = p_nilai,
      kelengkapan = p_kelengkapan,
      kesesuaian = p_kesesuaian,
      evaluator_id = p_evaluator_id,
      status_evaluasi = p_keputusan_guru::public.incident_status_enum
  where id = p_terlambat_id;

  if not found then
    raise exception 'record terlambat tidak ditemukan';
  end if;

  return v_id;
end;
$$;

revoke all on function public.record_task_evaluation(
  uuid, uuid, smallint, boolean, boolean, varchar, varchar, numeric, varchar, varchar
) from public, anon, authenticated;
grant execute on function public.record_task_evaluation(
  uuid, uuid, smallint, boolean, boolean, varchar, varchar, numeric, varchar, varchar
) to service_role;

-- 4) RLS.
alter table public.evaluasi_tugas enable row level security;
alter table public.decision_tree_models enable row level security;

-- Histori evaluasi dapat dibaca evaluator/admin, dan siswa hanya miliknya sendiri.
drop policy if exists evaluasi_tugas_select_authorized on public.evaluasi_tugas;
create policy evaluasi_tugas_select_authorized
on public.evaluasi_tugas
for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('guru', 'admin')
  )
  or exists (
    select 1 from public.terlambat t
    where t.id = evaluasi_tugas.terlambat_id
      and t.user_id = auth.uid()
  )
);

-- Tidak dibuat policy SELECT/INSERT/UPDATE/DELETE untuk decision_tree_models.
-- Edge Function memakai service role sehingga dapat membaca model aktif tanpa
-- mengekspos tree_json langsung kepada Flutter client.
drop policy if exists decision_tree_models_select_authenticated on public.decision_tree_models;

-- Tidak dibuat policy INSERT/UPDATE/DELETE untuk evaluasi_tugas.
-- Penyimpanan dilakukan melalui Edge Function submit-evaluation setelah
-- verifikasi role. Service role pada Edge Function melewati RLS.

-- 5) View anonim untuk export dataset. Tidak memuat user_id, nama, NISN, email,
-- atau photo_path.
create or replace view public.v_dataset_decision_tree as
select
  e.id as evaluation_id,
  e.nilai,
  case when e.kelengkapan then 1 else 0 end as kelengkapan,
  case when e.kesesuaian then 1 else 0 end as kesesuaian,
  e.keputusan_guru as target,
  e.decision_source,
  e.model_version,
  e.created_at
from public.evaluasi_tugas e;

commit;

-- ============================================================
-- CATATAN DEPLOYMENT
-- 1. Backup schema/data dahulu.
-- 2. Jalankan pada staging.
-- 3. Verifikasi enum role saat ini memang memuat admin/guru/siswa.
-- 4. Jika project memiliki RLS helper function tersendiri, policy di atas dapat
--    disesuaikan agar konsisten dengan standar repository.
-- ============================================================

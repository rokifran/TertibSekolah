-- ============================================================
-- SEED: 20 User Siswa
-- Jalan kan di Supabase SQL Editor (gunakan Service Role)
-- Password default: siswa123
-- Idempotent: user dengan email yang sudah ada akan dilewati.
-- ============================================================

DO $$
DECLARE
  siswa_data text[][] := ARRAY[
    ['Adi Putra',     'adi.putra@contoh.com',     'siswa123', 'X IPA 1',  '123456001'],
    ['Bunga Citra',   'bunga.citra@contoh.com',   'siswa123', 'X IPA 1',  '123456002'],
    ['Cahyo Nugroho', 'cahyo.nugroho@contoh.com', 'siswa123', 'X IPA 1',  '123456003'],
    ['Dewi Lestari',  'dewi.lestari@contoh.com',  'siswa123', 'X IPA 2',  '123456004'],
    ['Eko Prasetyo',  'eko.prasetyo@contoh.com',  'siswa123', 'X IPA 2',  '123456005'],
    ['Fitri Handayani','fitri.handayani@contoh.com','siswa123','X IPA 2',  '123456006'],
    ['Gilang Permana', 'gilang.permana@contoh.com','siswa123','X IPA 3',  '123456007'],
    ['Hesti Rahayu',  'hesti.rahayu@contoh.com',  'siswa123', 'X IPA 3',  '123456008'],
    ['Indra Saputra', 'indra.saputra@contoh.com', 'siswa123', 'X IPA 3',  '123456009'],
    ['Joko Widodo',   'joko.widodo@contoh.com',   'siswa123', 'XI IPA 1', '123456010'],
    ['Kartika Sari',  'kartika.sari@contoh.com',  'siswa123', 'XI IPA 1', '123456011'],
    ['Lukman Hakim',  'lukman.hakim@contoh.com',  'siswa123', 'XI IPA 1', '123456012'],
    ['Maya Anggraini','maya.anggraini@contoh.com','siswa123', 'XI IPA 2', '123456013'],
    ['Nanda Pratama', 'nanda.pratama@contoh.com', 'siswa123', 'XI IPA 2', '123456014'],
    ['Oktavia Dewi',  'oktavia.dewi@contoh.com',  'siswa123', 'XI IPA 2', '123456015'],
    ['Putra Ramadan', 'putra.ramadan@contoh.com', 'siswa123', 'XI IPA 3', '123456016'],
    ['Rina Amelia',   'rina.amelia@contoh.com',   'siswa123', 'XI IPA 3', '123456017'],
    ['Sandi Pratama', 'sandi.pratama@contoh.com', 'siswa123', 'XII IPA 1','123456018'],
    ['Tari Utami',    'tari.utami@contoh.com',    'siswa123', 'XII IPA 1','123456019'],
    ['Wahyu Hidayat', 'wahyu.hidayat@contoh.com', 'siswa123', 'XII IPA 1','123456020']
  ];

  idx int;
  v_id uuid;
  v_nama text;
  v_email text;
  v_password text;
  v_kelas text;
  v_nisn text;
  v_exists boolean;
  v_created int := 0;
BEGIN
  FOR idx IN 1..20 LOOP
    v_nama     := siswa_data[idx][1];
    v_email    := siswa_data[idx][2];
    v_password := siswa_data[idx][3];
    v_kelas    := siswa_data[idx][4];
    v_nisn     := siswa_data[idx][5];

    -- Lewati user yang email-nya sudah ada (idempotent)
    SELECT EXISTS (SELECT 1 FROM auth.users WHERE email = v_email) INTO v_exists;
    IF v_exists THEN
      RAISE NOTICE 'Skip (sudah ada): %', v_email;
      CONTINUE;
    END IF;

    v_id := gen_random_uuid();

    -- 1. Buat user di auth.users (password di-bcrypt, instance_id harus 0000-, semua kolom string harus '' bukan NULL)
    INSERT INTO auth.users (
      id, instance_id, email, encrypted_password,
      email_confirmed_at, aud, role,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      email_change_token_current, phone_change, reauthentication_token,
      created_at, updated_at
    ) VALUES (
      v_id, '00000000-0000-0000-0000-000000000000', v_email,
      crypt(v_password, gen_salt('bf', 10)),
      now(), 'authenticated', 'authenticated',
      '', '', '', '',
      '', '', '',
      now(), now()
    )
    ON CONFLICT (id) DO NOTHING;

    -- 2. Buat auth.identities (WAJIB - tanpa ini user tidak muncul di dashboard & tidak bisa login)
    INSERT INTO auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    VALUES (
      gen_random_uuid(),
      v_id::text,
      v_id,
      jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true, 'phone_verified', false),
      'email',
      now(), now(), now()
    );

    -- 3. Upsert ke profiles (idempotent, aman jika trigger handle_new_user sudah membuatnya)
    INSERT INTO public.profiles (id, email, full_name, role, created_at, updated_at)
    VALUES (v_id, v_email, v_nama, 'siswa', now(), now())
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        updated_at = now();

    -- 4. Pastikan detail_siswa ada (trigger on_profile_created_siswa biasanya membuatnya),
    --    lalu set kelas & nisn. Jangan timpa statistik disiplin.
    INSERT INTO public.detail_siswa (user_id, kelas, nisn, total_terlambat, total_menit_terlambat, status_disiplin)
    VALUES (v_id, v_kelas, v_nisn, 0, 0, 'aman')
    ON CONFLICT (user_id) DO UPDATE
    SET kelas = EXCLUDED.kelas,
        nisn = EXCLUDED.nisn;

    v_created := v_created + 1;
  END LOOP;

  RAISE NOTICE 'Selesai. % user siswa ditambahkan. Password default: siswa123', v_created;
END;
$$;
// supabase/functions/submit-evaluation/index.ts
// Edge Function: Simpan histori evaluasi tugas siswa.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Tidak terautentikasi: Missing Authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const token = authHeader.replace('Bearer ', '');
    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userError } = await supabaseUser.auth.getUser(token);
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Token tidak valid' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const { data: profile, error: profileError } = await supabaseUser
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: 'Profil tidak ditemukan' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const role: string = profile.role;
    if (role !== 'guru' && role !== 'admin') {
      return new Response(
        JSON.stringify({ error: 'Hanya guru atau admin yang dapat menyimpan evaluasi' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const body = await req.json();
    const terlambatId: string = body.terlambat_id;
    const nilai: number = Number(body.nilai);
    const kelengkapan: boolean = body.kelengkapan === true || body.kelengkapan === 1;
    const kesesuaian: boolean = body.kesesuaian === true || body.kesesuaian === 1;
    const keputusanGuru: string = body.keputusan_guru;
    const prediksiModel: string | null = body.prediksi_model ?? null;
    const predictionConfidence: number | null = body.prediction_confidence ?? null;
    const modelVersion: string | null = body.model_version ?? null;
    const decisionSource: string = body.decision_source ?? 'manual';

    if (!terlambatId) {
      return new Response(
        JSON.stringify({ error: 'terlambat_id wajib diisi' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }
    if (isNaN(nilai) || nilai < 0 || nilai > 100) {
      return new Response(
        JSON.stringify({ error: 'nilai harus angka 0-100' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }
    if (keputusanGuru !== 'selesai' && keputusanGuru !== 'revisi') {
      return new Response(
        JSON.stringify({ error: 'keputusan_guru harus selesai atau revisi' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: evaluasiId, error: rpcErr } = await supabaseAdmin.rpc(
      'record_task_evaluation',
      {
        p_terlambat_id: terlambatId,
        p_evaluator_id: user.id,
        p_nilai: nilai,
        p_kelengkapan: kelengkapan,
        p_kesesuaian: kesesuaian,
        p_keputusan_guru: keputusanGuru,
        p_prediksi_model: prediksiModel,
        p_prediction_confidence: predictionConfidence,
        p_model_version: modelVersion,
        p_decision_source: decisionSource,
      },
    );

    if (rpcErr) throw rpcErr;

    return new Response(
      JSON.stringify({ evaluation_id: evaluasiId }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('[submit-evaluation]', err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});

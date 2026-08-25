// supabase/functions/predict-evaluation/index.ts
// Edge Function: Prediksi Decision Tree untuk evaluasi tugas siswa.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface LeafNode {
  type: 'leaf';
  class: string;
  confidence: number;
  samples: number;
  distribution: Record<string, number>;
}

interface InternalNode {
  type: 'node';
  feature: 'nilai' | 'kelengkapan' | 'kesesuaian';
  threshold: number;
  samples: number;
  left: TreeNode;
  right: TreeNode;
}

type TreeNode = LeafNode | InternalNode;

interface TreeJson {
  version: string;
  features: string[];
  classes: string[];
  criterion: string;
  max_depth: number;
  random_state: number;
  root: TreeNode;
}

function traverseTree(
  node: TreeNode,
  features: Record<string, number>,
): { prediksi: string; confidence: number } {
  if (node.type === 'leaf') {
    return { prediksi: node.class, confidence: node.confidence };
  }

  const val = features[node.feature] ?? 0;
  const next = val <= node.threshold ? node.left : node.right;
  return traverseTree(next, features);
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const nilai: number = Number(body.nilai);
    const kelengkapan: number = body.kelengkapan === true || body.kelengkapan === 1 ? 1 : 0;
    const kesesuaian: number = body.kesesuaian === true || body.kesesuaian === 1 ? 1 : 0;

    if (isNaN(nilai) || nilai < 0 || nilai > 100) {
      return new Response(
        JSON.stringify({ error: 'nilai harus angka 0-100' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: modelRow, error: modelErr } = await supabaseAdmin
      .from('decision_tree_models')
      .select('version, tree_json')
      .eq('is_active', true)
      .maybeSingle();

    if (modelErr) throw modelErr;

    if (!modelRow) {
      return new Response(
        JSON.stringify({ model_active: false }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const tree = modelRow.tree_json as TreeJson;
    const featureMap: Record<string, number> = { nilai, kelengkapan, kesesuaian };
    const { prediksi, confidence } = traverseTree(tree.root, featureMap);

    return new Response(
      JSON.stringify({
        model_active: true,
        prediksi,
        confidence,
        model_version: modelRow.version,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('[predict-evaluation]', err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});

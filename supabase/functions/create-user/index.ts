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
    console.log("SUPABASE_URL from env:", Deno.env.get('SUPABASE_URL'));
    console.log("SUPABASE_SERVICE_ROLE_KEY exists:", !!Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'));
    
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Verify user authorization
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Missing Authorization header');

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(token);
    if (userError || !user) {
      throw new Error('Unauthorized');
    }

    // Check if the caller is an Admin in public.profiles (V2 Schema)
    const { data: userData, error: roleError } = await supabaseClient
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    if (roleError || !userData) {
      console.error('Role verification failed:', roleError);
      throw new Error('Could not verify user role');
    }

    if (userData.role !== 'admin') {
      throw new Error('Forbidden: Only admin can create users');
    }

    // Get the request payload
    const { email, password, nama, role } = await req.json();

    if (!email || !password || !nama || !role) {
      throw new Error('Missing required fields');
    }

    // Validate role input
    if (role !== 'guru' && role !== 'siswa' && role !== 'admin') {
      throw new Error('Invalid role specified');
    }

    // Create user in Auth using Admin API
    const { data: newUser, error: createError } = await supabaseClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { nama, role },
    });

    if (createError) throw createError;

    // Insert/Update user details into public.profiles (V2 Schema)
    const { error: insertError } = await supabaseClient
      .from('profiles')
      .upsert({
        id: newUser.user.id,
        email,
        full_name: nama,
        role: role,
      });

    if (insertError) {
      // Rollback auth user creation if inserting into public.profiles fails
      await supabaseClient.auth.admin.deleteUser(newUser.user.id);
      throw insertError;
    }

    // For V2 Schema: If role is 'siswa', we need to ensure detail_siswa row exists.
    if (role === 'siswa') {
      const { error: detailError } = await supabaseClient
        .from('detail_siswa')
        .upsert({
          user_id: newUser.user.id,
          total_terlambat: 0,
          total_menit_terlambat: 0,
          status_disiplin: 'aman',
        });

      if (detailError) {
        // Rollback profiles and auth user
        await supabaseClient.from('profiles').delete().eq('id', newUser.user.id);
        await supabaseClient.auth.admin.deleteUser(newUser.user.id);
        throw detailError;
      }
    }

    return new Response(JSON.stringify({ message: 'User created successfully', user: newUser.user }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    const errorDetails = error instanceof Error
      ? { message: error.message, name: error.name, stack: error.stack }
      : typeof error === 'object' && error !== null
        ? { ...error, message: (error as any).message || String(error) }
        : { message: String(error) };
    console.error('Error occurred in Edge Function:', error);
    return new Response(JSON.stringify({ error: errorDetails }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});

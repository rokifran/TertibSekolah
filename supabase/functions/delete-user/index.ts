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
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error('Supabase environment variables are missing');
    }

    const supabaseClient = createClient(supabaseUrl, serviceRoleKey);

    // Verify user authorization
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Missing Authorization header');

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(token);
    if (userError || !user) {
      throw new Error('Unauthorized');
    }

    // Check if caller is an Admin in public.profiles
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
      throw new Error('Forbidden: Only admin can delete users');
    }

    // Get the request payload
    const { userId } = await req.json();

    if (!userId) {
      throw new Error('Missing required field: userId');
    }

    if (userId === user.id) {
      throw new Error('Tidak dapat menghapus akun admin yang sedang digunakan');
    }

    // 1. Delete from detail_siswa if exists
    await supabaseClient.from('detail_siswa').delete().eq('user_id', userId);

    // 2. Delete from profiles if exists
    await supabaseClient.from('profiles').delete().eq('id', userId);

    // 3. Delete user from Supabase Authentication using Admin API
    const { error: deleteAuthError } = await supabaseClient.auth.admin.deleteUser(userId);
    if (deleteAuthError) {
      console.error('Error deleting user from Supabase Auth:', deleteAuthError);
      throw deleteAuthError;
    }

    return new Response(
      JSON.stringify({ message: 'User and Auth account deleted successfully' }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );
  } catch (error) {
    const errorDetails = error instanceof Error
      ? { message: error.message, name: error.name }
      : typeof error === 'object' && error !== null
        ? { ...error, message: (error as any).message || String(error) }
        : { message: String(error) };

    console.error('Error in Edge Function delete-user:', error);
    return new Response(
      JSON.stringify({ error: errorDetails }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});

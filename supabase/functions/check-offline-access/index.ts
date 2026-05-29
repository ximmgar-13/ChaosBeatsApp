import { createSupabaseClient, corsHeaders, handleCors } from "../_shared/mod.ts";

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const { song_ids } = await req.json();

    if (!song_ids || !Array.isArray(song_ids) || song_ids.length === 0) {
      throw new Error("song_ids array is required");
    }

    if (song_ids.length > 50) {
      throw new Error("Max 50 song_ids per request");
    }

    const supabase = createSupabaseClient(req);

    const { data: user, error: userError } = await supabase.auth.getUser();
    if (userError || !user.user) throw new Error("Unauthorized");

    const { data: membership } = await supabase
      .from("user_memberships")
      .select("status, plan_type")
      .eq("user_id", user.user.id)
      .in("status", ["active", "trialing"])
      .maybeSingle();

    const isPremium = !!membership;

    const { data: songs, error } = await supabase
      .from("songs")
      .select("id, is_offline_available")
      .in("id", song_ids);

    if (error) throw error;

    const offlineMap: Record<string, boolean> = {};
    for (const song of songs || []) {
      offlineMap[song.id] = song.is_offline_available && isPremium;
    }

    return new Response(
      JSON.stringify({ offline_access: offlineMap, is_premium: isPremium }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

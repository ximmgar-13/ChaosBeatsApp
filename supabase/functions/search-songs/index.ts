import { createSupabaseClient, corsHeaders, handleCors } from "../_shared/mod.ts";

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const url = new URL(req.url);
    const query = url.searchParams.get("q") || "";
    const genre = url.searchParams.get("genre");
    const limit = Math.min(Number(url.searchParams.get("limit")) || 20, 50);
    const offset = Number(url.searchParams.get("offset")) || 0;

    const supabase = createSupabaseClient(req);

    let builder = supabase
      .from("songs")
      .select("id, title, album, genre, duration_seconds, cover_url, artist:users!songs_artist_id_fkey(id, username, display_name, avatar_url)")
      .eq("status", "published")
      .order("created_at", { ascending: false })
      .range(offset, offset + limit - 1);

    if (query) {
      builder = builder.or(`title.ilike.%${query}%,album.ilike.%${query}%`);
    }

    if (genre) {
      builder = builder.eq("genre", genre);
    }

    const { data, error, count } = await builder;

    if (error) throw error;

    return new Response(
      JSON.stringify({ data, count, query, genre }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

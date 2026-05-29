import { createServiceClient, corsHeaders, handleCors } from "../_shared/mod.ts";

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const { user_id, title, body, type, data: extraData } = await req.json();

    if (!user_id || !title) {
      throw new Error("user_id and title are required");
    }

    const supabase = createServiceClient();

    const { error: insertError } = await supabase
      .from("notifications")
      .insert({
        user_id,
        title,
        body: body || "",
        type: type || "system",
        data: extraData || null,
      });

    if (insertError) throw insertError;

    // Here you would integrate with Expo Push Notifications
    // const { data: settings } = await supabase
    //   .from("user_settings")
    //   .select("push_notifications_enabled")
    //   .eq("user_id", user_id)
    //   .single();
    //
    // if (settings?.push_notifications_enabled) {
    //   const { data: profile } = await supabase
    //     .from("users")
    //     .select("expo_push_token")
    //     .eq("id", user_id)
    //     .single();
    //
    //   if (profile?.expo_push_token) {
    //     await fetch("https://exp.host/--/api/v2/push/send", {
    //       method: "POST",
    //       headers: { "Content-Type": "application/json" },
    //       body: JSON.stringify({
    //         to: profile.expo_push_token,
    //         title,
    //         body,
    //         data: extraData,
    //       }),
    //     });
    //   }
    // }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

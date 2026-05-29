import { corsHeaders, handleCors } from "../_shared/mod.ts";

interface VersionConfig {
  minimum_version: string;
  latest_version: string;
  update_url: string;
  force_update: boolean;
  release_notes: string;
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const { platform, current_version } = await req.json();

    if (!platform || !current_version) {
      throw new Error("platform and current_version are required");
    }

    if (!["ios", "android"].includes(platform)) {
      throw new Error("platform must be 'ios' or 'android'");
    }

    const configs: Record<string, VersionConfig> = {
      ios: {
        minimum_version: "1.0.0",
        latest_version: "1.0.1",
        update_url: "https://apps.apple.com/app/chaosbeats/id0000000000",
        force_update: false,
        release_notes: "Correcciones de estabilidad y mejor rendimiento",
      },
      android: {
        minimum_version: "1.0.0",
        latest_version: "1.0.1",
        update_url: "https://play.google.com/store/apps/details?id=com.chaosbeats.app",
        force_update: false,
        release_notes: "Correcciones de estabilidad y mejor rendimiento",
      },
    };

    const config = configs[platform];

    const cmp = (a: string, b: string) => {
      const pa = a.split(".").map(Number);
      const pb = b.split(".").map(Number);
      for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
        const diff = (pa[i] || 0) - (pb[i] || 0);
        if (diff !== 0) return diff;
      }
      return 0;
    };

    const needsUpdate = cmp(current_version, config.latest_version) < 0;
    const isForceUpdate = cmp(current_version, config.minimum_version) < 0;

    return new Response(
      JSON.stringify({
        needs_update: needsUpdate,
        force_update: isForceUpdate || config.force_update,
        latest_version: config.latest_version,
        update_url: config.update_url,
        release_notes: config.release_notes,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

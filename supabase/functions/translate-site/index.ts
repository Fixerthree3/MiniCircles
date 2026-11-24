const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const supportedTargets = new Set([
  "af",
  "nr",
  "xh",
  "zu",
  "nso",
  "st",
  "tn",
  "ss",
  "ve",
  "ts",
]);

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return reply(405, { error: "Method not allowed." });
  }

  const apiKey = Deno.env.get("GOOGLE_TRANSLATE_API_KEY");
  if (!apiKey) {
    console.error("The Google Cloud Translation API key is not configured.");
    return reply(503, { error: "Site translation is not configured." });
  }

  let payload: { target?: unknown; texts?: unknown };
  try {
    payload = await request.json();
  } catch {
    return reply(400, { error: "A valid request body is required." });
  }
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return reply(400, { error: "A valid request body is required." });
  }
  if (typeof payload.target !== "string" || !supportedTargets.has(payload.target)) {
    return reply(400, { error: "Choose a supported South African language." });
  }
  if (!Array.isArray(payload.texts) || payload.texts.length < 1 || payload.texts.length > 100) {
    return reply(400, { error: "Send between 1 and 100 text items." });
  }
  if (payload.texts.some((text) => typeof text !== "string" || !text.trim() || text.length > 16000)) {
    return reply(400, { error: "Text items must be non-empty strings of 16,000 characters or fewer." });
  }
  const texts = payload.texts as string[];
  if (texts.reduce((total, text) => total + text.length, 0) > 18000) {
    return reply(400, { error: "The combined text must be 18,000 characters or fewer." });
  }

  let providerResponse: Response;
  try {
    providerResponse = await fetch(
      `https://translation.googleapis.com/language/translate/v2?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ q: texts, target: payload.target, format: "text" }),
      },
    );
  } catch (error) {
    console.error("Could not reach Google Cloud Translation.", error);
    return reply(502, { error: "The translation service could not be reached." });
  }
  if (!providerResponse.ok) {
    console.error("Google Cloud Translation returned an error.", providerResponse.status);
    return reply(502, { error: "The translation service could not translate this page." });
  }

  let providerPayload: { data?: { translations?: unknown } };
  try {
    providerPayload = await providerResponse.json();
  } catch {
    console.error("Google Cloud Translation returned an invalid response.");
    return reply(502, { error: "The translation service returned an invalid response." });
  }
  const results = providerPayload.data?.translations;
  if (
    !Array.isArray(results) ||
    results.length !== texts.length ||
    results.some((item) => !item || typeof item !== "object" || typeof item.translatedText !== "string")
  ) {
    console.error("Google Cloud Translation returned an incomplete translation batch.");
    return reply(502, { error: "The translation service returned an incomplete response." });
  }

  return reply(200, {
    translations: results.map((item) => (item as { translatedText: string }).translatedText),
  });
});

// Supabase Edge Function: "curiosita" — curiosità del libro, MULTI-PROVIDER e silenziosa.
// Prova i provider con piano gratuito SENZA carta (Groq → OpenRouter → Gemini).
// NON restituisce mai 429/502: se nessun provider risponde → 200 {unavailable:true}
// e il frontend ripiega su Wikidata/Wikipedia (nessun errore in console).
// Secret consigliato:  supabase secrets set GROQ_API_KEY=...   (gratis, niente carta)

const GROQ = Deno.env.get("GROQ_API_KEY") || "";
const OPENROUTER = Deno.env.get("OPENROUTER_API_KEY") || "";
const GEMINI = Deno.env.get("GEMINI_API_KEY") || "";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

function buildPrompt(title: string, author: string, originalTitle: string, genre: string) {
  return `Sei un curatore letterario. Proponi UNA sola curiosità VERA e interessante sul libro "${title}"${author ? ` di ${author}` : ""}${originalTitle ? ` (titolo originale: "${originalTitle}")` : ""}${genre ? ` [genere: ${genre}]` : ""}.
Regole: in ITALIANO, max 45 parole, NESSUNO SPOILER, niente frasi banali. Preferisci aneddoti su autore/scrittura, contesto, adattamenti, premi, pubblicazione, titolo. Se non sei certo, dai un'informazione generale e prudente; non inventare.
Scegli una categoria tra: Autore, Dietro le quinte, Adattamenti, Riconoscimenti, Pubblicazione, Contesto, Genere, Titolo.
Rispondi SOLO con JSON valido: {"categoria":"<categoria>","testo":"<curiosità>"}`;
}
function parseJSON(raw: string) {
  const m = (raw || "").match(/\{[\s\S]*\}/);
  if (m) { try { return JSON.parse(m[0]); } catch { /* */ } }
  const t = (raw || "").replace(/```json|```/g, "").trim();
  return t ? { categoria: "Curiosità", testo: t } : null;
}
async function viaOpenAI(url: string, key: string, model: string, prompt: string) {
  const r = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": `Bearer ${key}` },
    body: JSON.stringify({ model, messages: [{ role: "user", content: prompt }], temperature: 0.7, max_tokens: 300 }),
  });
  if (!r.ok) return null;
  const d = await r.json();
  return parseJSON(d?.choices?.[0]?.message?.content || "");
}
async function viaGemini(key: string, prompt: string) {
  const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${key}`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ contents: [{ role: "user", parts: [{ text: prompt }] }], generationConfig: { temperature: 0.7, maxOutputTokens: 300 } }),
  });
  if (!r.ok) return null;
  const d = await r.json();
  return parseJSON((d?.candidates?.[0]?.content?.parts || []).map((p: any) => p.text || "").join(""));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { title = "", author = "", originalTitle = "", genre = "" } = await req.json();
    if (!title) return json({ unavailable: true });
    const prompt = buildPrompt(title, author, originalTitle, genre);

    const providers: Array<() => Promise<any>> = [];
    if (GROQ) providers.push(() => viaOpenAI("https://api.groq.com/openai/v1/chat/completions", GROQ, "llama-3.3-70b-versatile", prompt));
    if (OPENROUTER) providers.push(() => viaOpenAI("https://openrouter.ai/api/v1/chat/completions", OPENROUTER, "meta-llama/llama-3.3-70b-instruct:free", prompt));
    if (GEMINI) providers.push(() => viaGemini(GEMINI, prompt));

    for (const run of providers) {
      try {
        const out = await run();
        if (out && out.testo) return json({ categoria: out.categoria || "Curiosità", testo: out.testo, web: false });
      } catch (_) { /* prova il prossimo */ }
    }
    return json({ unavailable: true });   // nessun provider → fallback lato client (Wikidata)
  } catch (e) {
    return json({ unavailable: true, reason: String(e) });
  }
});

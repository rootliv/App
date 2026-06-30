// Supabase Edge Function: "assistente" — assistente del club del libro, MULTI-PROVIDER.
// Prova in ordine i provider per cui esiste una chiave (secret), tutti con piani GRATUITI
// e SENZA carta di credito per ottenere la chiave:
//   1) GROQ_API_KEY      → console.groq.com  (Llama, veloce, free, no carta)
//   2) OPENROUTER_API_KEY→ openrouter.ai      (modelli :free, free, no carta)
//   3) GEMINI_API_KEY    → aistudio.google.com (free)
// Non restituisce MAI 502: se nessun provider risponde → 200 {unavailable:true}
// così il frontend usa l'"Assistente base gratuito". Imposta i secret con:
//   supabase secrets set GROQ_API_KEY=...   (poi: supabase functions deploy assistente)

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

const SYSTEM =
`Sei "Pàgina AI", l'assistente di un'app per club del libro. Rispondi SEMPRE in italiano, con tono caldo, competente e ordinato.
Puoi: consigliare libri (indica Titolo e Autore), generare domande di discussione, proporre temi di dibattito, spiegare contesto storico/culturale, suggerire citazioni famose, e spiegare come usare l'app (note nel diario che si sbloccano per pagina, progresso di lettura, club, sorteggio/votazione, incontri).
Regole: NIENTE SPOILER (no finali, colpi di scena, morti, identità segrete). Conciso ma completo; usa elenchi puntati quando aiutano.`;

function buildUserPrompt(message: string, ctx: any): string {
  const lines = [
    ctx?.reading ? `Sta leggendo: "${ctx.reading.title}" di ${ctx.reading.author}.` : "",
    (ctx?.genres?.length) ? `Generi preferiti: ${ctx.genres.join(", ")}.` : "",
    (ctx?.authors?.length) ? `Autori preferiti: ${ctx.authors.join(", ")}.` : "",
    (ctx?.library?.length) ? `Alcuni libri in libreria: ${ctx.library.slice(0, 25).join("; ")}.` : "",
  ].filter(Boolean).join("\n");
  return `Contesto utente:\n${lines || "(nessun dato)"}\n\nMessaggio dell'utente:\n${message}`;
}

async function viaOpenAICompatible(url: string, key: string, model: string, message: string, ctx: any) {
  const r = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": `Bearer ${key}` },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: SYSTEM },
        { role: "user", content: buildUserPrompt(message, ctx) },
      ],
      temperature: 0.6, max_tokens: 800,
    }),
  });
  if (!r.ok) return null;
  const d = await r.json();
  const a = d?.choices?.[0]?.message?.content;
  return (a && a.trim()) ? a.trim() : null;
}

async function viaGemini(key: string, message: string, ctx: any) {
  const r = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${key}`,
    {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: SYSTEM + "\n\n" + buildUserPrompt(message, ctx) }] }],
        generationConfig: { temperature: 0.6, maxOutputTokens: 800 },
      }),
    },
  );
  if (!r.ok) return null;
  const d = await r.json();
  const a = (d?.candidates?.[0]?.content?.parts || []).map((p: any) => p.text || "").join("").trim();
  return a || null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { message, context } = await req.json();
    if (!message || !String(message).trim()) return json({ error: "message mancante" }, 400);
    const ctx = context || {};

    const providers: Array<[string, () => Promise<string | null>]> = [];
    if (GROQ) providers.push(["Groq (Llama 3.3)", () => viaOpenAICompatible("https://api.groq.com/openai/v1/chat/completions", GROQ, "llama-3.3-70b-versatile", message, ctx)]);
    if (OPENROUTER) providers.push(["OpenRouter", () => viaOpenAICompatible("https://openrouter.ai/api/v1/chat/completions", OPENROUTER, "meta-llama/llama-3.3-70b-instruct:free", message, ctx)]);
    if (GEMINI) providers.push(["Gemini", () => viaGemini(GEMINI, message, ctx)]);

    for (const [name, run] of providers) {
      try {
        const a = await run();
        if (a) return json({ answer: a, provider: name });
      } catch (_) { /* prova il prossimo */ }
    }
    // nessun provider disponibile/funzionante → il frontend userà l'assistente base
    return json({ unavailable: true });
  } catch (e) {
    return json({ unavailable: true, reason: String(e) });
  }
});

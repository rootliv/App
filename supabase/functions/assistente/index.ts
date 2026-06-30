// Supabase Edge Function: "assistente"
// Assistente AI reale del club del libro, basato su Gemini.
// Riceve la domanda dell'utente + un po' di contesto (libro in lettura, generi/autori,
// libreria) e risponde in italiano, senza spoiler. La chiave Gemini resta lato server.
// Deploy:  supabase functions deploy assistente
// (usa lo stesso secret GEMINI_API_KEY della function "curiosita")

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";
const MODEL = "gemini-2.0-flash";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(b: unknown, s = 200) {
  return new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (!GEMINI_API_KEY) return json({ error: "GEMINI_API_KEY non configurata" }, 500);
  try {
    const { message, context } = await req.json();
    if (!message || !String(message).trim()) return json({ error: "message mancante" }, 400);
    const ctx = context || {};

    const sys =
`Sei "Pàgina AI", l'assistente di un'app per club del libro. Rispondi SEMPRE in italiano, con tono caldo, competente e ordinato.
Cosa puoi fare: consigliare libri (indica sempre Titolo e Autore), generare domande di discussione per il club, proporre temi di dibattito, spiegare contesto storico/culturale e riferimenti, proporre citazioni famose, aiutare nella lettura.
Regole: NON fare spoiler (niente finali, colpi di scena, morti, identità segrete). Sii conciso ma completo. Usa elenchi puntati quando aiutano la chiarezza. Se l'utente chiede di trovare un libro specifico, dai con precisione Titolo e Autore.`;

    const ctxLines = [
      ctx.reading ? `Sta leggendo: "${ctx.reading.title}" di ${ctx.reading.author}.` : "",
      (ctx.genres && ctx.genres.length) ? `Generi preferiti: ${ctx.genres.join(", ")}.` : "",
      (ctx.authors && ctx.authors.length) ? `Autori preferiti: ${ctx.authors.join(", ")}.` : "",
      (ctx.library && ctx.library.length) ? `Alcuni libri nella sua libreria: ${ctx.library.slice(0, 25).join("; ")}.` : "",
    ].filter(Boolean).join("\n");

    const prompt = `${sys}\n\nContesto utente:\n${ctxLines || "(nessun dato disponibile)"}\n\nMessaggio dell'utente:\n${message}`;

    const r = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.6, maxOutputTokens: 700 },
        }),
      },
    );
    if (!r.ok) return json({ error: "gemini " + r.status, detail: await r.text() }, 502);
    const d = await r.json();
    const answer = (d?.candidates?.[0]?.content?.parts || [])
      .map((p: { text?: string }) => p.text || "").join("").trim();
    if (!answer) return json({ error: "vuota" }, 502);
    return json({ answer });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

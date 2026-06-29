// Supabase Edge Function: "curiosita"
// Genera UNA curiosità letteraria in italiano, VERA e senza spoiler, usando
// Gemini con "Google Search grounding" (AI con accesso reale al web).
// La chiave Gemini resta SOLO lato server (secret GEMINI_API_KEY) e non è mai
// esposta nel sito. Deploy:  supabase functions deploy curiosita
// Secret:  supabase secrets set GEMINI_API_KEY=la_tua_chiave

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";
const MODEL = "gemini-2.0-flash"; // supporta il grounding con Google Search

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (!GEMINI_API_KEY) return json({ error: "GEMINI_API_KEY non configurata" }, 500);

  try {
    const { title = "", author = "", originalTitle = "", genre = "" } = await req.json();
    if (!title) return json({ error: "title mancante" }, 400);

    const prompt =
`Sei un curatore letterario esperto. Cerca sul web e proponi UNA sola curiosità VERA e VERIFICABILE sul libro "${title}"${author ? ` di ${author}` : ""}${originalTitle ? ` (titolo originale: "${originalTitle}")` : ""}${genre ? ` [genere: ${genre}]` : ""}.

Regole tassative:
- Scrivi in ITALIANO, massimo 45 parole, tono coinvolgente.
- NESSUNO SPOILER: non rivelare finali, morti di personaggi, colpi di scena, identità segrete, soluzioni di misteri o eventi decisivi della trama.
- Niente frasi banali ("è molto famoso", "è un bel libro").
- Preferisci: aneddoti sull'autore o sulla scrittura, contesto storico/culturale, ispirazioni (senza spoiler), adattamenti cinema/TV usciti, premi e riconoscimenti, prima pubblicazione, differenza col titolo originale, accoglienza del pubblico, influenza culturale.
- Basati su fonti attendibili trovate con la ricerca. Se non trovi nulla di certo, dai un'informazione generale e prudente su autore/genere, senza inventare fatti.
- Scegli una categoria tra: Autore, Dietro le quinte, Adattamenti, Riconoscimenti, Pubblicazione, Contesto, Genere, Titolo.

Rispondi SOLO con un oggetto JSON valido, senza testo extra:
{"categoria":"<una delle categorie>","testo":"<la curiosità>"}`;

    const url = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}`;
    const base = {
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.7, maxOutputTokens: 400 },
    };
    const call = (body: unknown) =>
      fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });

    // 1) prova con accesso al web (Google Search grounding)
    let usedWeb = true;
    let r = await call({ ...base, tools: [{ google_search: {} }] });
    // 2) la ricerca web (grounding) sul piano gratuito spesso dà 429/400/403:
    //    in tal caso riprova SENZA web, così l'AI funziona comunque
    if (!r.ok && (r.status === 400 || r.status === 403 || r.status === 429)) {
      usedWeb = false;
      r = await call(base);
    }
    if (!r.ok) {
      const status = r.status;
      const detail = await r.text();
      const msg = status === 429
        ? "Limite richieste Gemini raggiunto: riprova tra poco (la curiosità è settimanale, in uso normale non accade)."
        : ("gemini " + status);
      return json({ error: msg, status, detail }, status === 429 ? 429 : 502);
    }
    const d = await r.json();
    const raw = (d?.candidates?.[0]?.content?.parts || [])
      .map((p: { text?: string }) => p.text || "").join("").trim();

    let out: { categoria?: string; testo?: string } = {};
    const m = raw.match(/\{[\s\S]*\}/);
    if (m) { try { out = JSON.parse(m[0]); } catch { /* ignore */ } }
    if (!out.testo) out = { categoria: "Curiosità", testo: raw.replace(/```json|```/g, "").trim() };

    if (!out.testo) return json({ error: "vuota" }, 502);
    return json({ categoria: out.categoria || "Curiosità", testo: out.testo, web: usedWeb });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

// Supabase Edge Function: "delete-account" — permette a un utente autenticato di eliminare
// definitivamente il proprio account e i propri dati.
//
// Sicurezza:
// - L'utente da eliminare NON è mai preso da un id passato dal client: viene sempre derivato
//   dal JWT presente nell'header Authorization della richiesta, verificato da Supabase Auth.
//   Questo impedisce a un utente di eliminare l'account di un altro.
// - Richiede la password attuale nel body e la riverifica con signInWithPassword prima di
//   procedere: un token di sessione rubato (es. da un XSS) non basta da solo per eliminare
//   l'account. Questo passaggio passa anche attraverso l'eventuale hook anti brute-force
//   (Password Verification Hook) già configurato per il login.
// - Solo dopo la verifica viene usata la Service Role Key (mai esposta al client) per:
//     1) rimuovere i dati applicativi noti che appartengono all'utente (best effort);
//     2) cancellare l'utente da auth.users tramite l'Admin API.
//
// Limite noto: questa è una pulizia applicativa "best effort" sulle tabelle note al momento
// della scrittura (books, notes, votes, proposals, club_members, clubs, meetings,
// password_verification_attempts). Se in futuro aggiungi nuove tabelle con dati personali,
// aggiorna anche questa funzione. Per una garanzia strutturale, valuta anche vincoli
// ON DELETE CASCADE/SET NULL dalle tue tabelle verso auth.users(id) — vedi il report.

import { createClient } from "npm:@supabase/supabase-js@2.110.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")
  || (() => { try { return JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") || "{}").default || ""; } catch { return ""; } })();
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
  || (() => { try { return JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}").default || ""; } catch { return ""; } })();
const ALLOWED_ORIGIN = Deno.env.get("ALLOWED_ORIGIN") || "*";

const cors = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

// Rate limiting best-effort per istanza, per contenere richieste ripetute/abuso.
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX_REQ = 5;
const hits = new Map<string, number[]>();
function rateLimited(key: string): boolean {
  const now = Date.now();
  const arr = (hits.get(key) || []).filter((t) => now - t < RATE_LIMIT_WINDOW_MS);
  arr.push(now);
  hits.set(key, arr);
  if (hits.size > 5000) { const k0 = hits.keys().next().value; if (k0) hits.delete(k0); }
  return arr.length > RATE_LIMIT_MAX_REQ;
}
function clientKey(req: Request): string {
  return req.headers.get("x-forwarded-for")?.split(",")[0].trim()
    || req.headers.get("cf-connecting-ip")
    || "unknown";
}

async function cleanupUserData(admin: ReturnType<typeof createClient>, uid: string) {
  // Ogni passo è indipendente e best-effort: un fallimento su una tabella non deve
  // bloccare la cancellazione delle altre né dell'account stesso.
  const safe = async (label: string, fn: () => Promise<unknown>) => {
    try { await fn(); } catch (e) { console.error(`delete-account cleanup [${label}] error:`, e); }
  };

  await safe("books", () => admin.from("books").delete().eq("user_id", uid));
  await safe("notes", () => admin.from("notes").delete().eq("user_id", uid));
  await safe("votes", () => admin.from("votes").delete().eq("user_id", uid));
  await safe("proposals", () => admin.from("proposals").delete().eq("user_id", uid));
  await safe("password_verification_attempts", () => admin.from("password_verification_attempts").delete().eq("user_id", uid));

  // Club di cui è owner: se ci sono altri membri, trasferisci la proprietà invece di
  // distruggere il club per tutti; se è l'unico membro, elimina il club e il suo contenuto.
  try {
    const { data: ownedClubs } = await admin.from("clubs").select("id").eq("owner", uid);
    for (const club of ownedClubs || []) {
      const { data: others } = await admin.from("club_members")
        .select("user_id,role").eq("club_id", club.id).neq("user_id", uid);
      if (others && others.length) {
        const newOwner = others.find((m: any) => m.role === "admin") || others[0];
        await safe(`clubs.owner(${club.id})`, () => admin.from("clubs").update({ owner: newOwner.user_id }).eq("id", club.id));
        await safe(`meetings.created_by(${club.id})`, () => admin.from("meetings").update({ created_by: newOwner.user_id }).eq("club_id", club.id).eq("created_by", uid));
      } else {
        await safe(`meetings(${club.id})`, () => admin.from("meetings").delete().eq("club_id", club.id));
        await safe(`notes(${club.id})`, () => admin.from("notes").delete().eq("club_id", club.id));
        await safe(`proposals(${club.id})`, () => admin.from("proposals").delete().eq("club_id", club.id));
        await safe(`votes(${club.id})`, () => admin.from("votes").delete().eq("club_id", club.id));
        await safe(`club_members(${club.id})`, () => admin.from("club_members").delete().eq("club_id", club.id));
        await safe(`clubs(${club.id})`, () => admin.from("clubs").delete().eq("id", club.id));
      }
    }
  } catch (e) { console.error("delete-account cleanup [clubs] error:", e); }

  // Membership rimanenti (club di cui NON è owner) e profilo.
  await safe("club_members", () => admin.from("club_members").delete().eq("user_id", uid));
  await safe("profiles", () => admin.from("profiles").delete().eq("id", uid));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  if (!SUPABASE_URL || !ANON_KEY || !SERVICE_KEY) {
    console.error("delete-account: missing SUPABASE_URL/ANON_KEY/SERVICE_KEY env vars");
    return json({ error: "Configurazione del server incompleta." }, 500);
  }

  try {
    if (rateLimited(clientKey(req))) return json({ error: "Troppi tentativi. Riprova più tardi." }, 429);

    const authHeader = req.headers.get("authorization") || req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Non autenticato." }, 401);

    let body: any;
    try { body = await req.json(); } catch { return json({ error: "JSON non valido." }, 400); }
    const password = typeof body?.password === "string" ? body.password : "";
    if (!password) return json({ error: "Password richiesta per confermare l'eliminazione." }, 400);

    // 1) Identifica l'utente chiamante dal JWT (mai da un id fornito dal client).
    const callerClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: userRes, error: userErr } = await callerClient.auth.getUser();
    if (userErr || !userRes?.user) return json({ error: "Sessione non valida. Accedi di nuovo." }, 401);
    const user = userRes.user;
    if (!user.email) return json({ error: "Account senza email: contatta il supporto." }, 400);

    // 2) Riverifica la password (indipendente dal token di sessione già posseduto).
    const verifyClient = createClient(SUPABASE_URL, ANON_KEY);
    const { error: pwErr } = await verifyClient.auth.signInWithPassword({ email: user.email, password });
    if (pwErr) return json({ error: "Password non corretta." }, 401);

    // 3) Pulizia dati applicativi + cancellazione dell'utente (Service Role, mai esposta al client).
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);
    await cleanupUserData(admin, user.id);
    const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
    if (delErr) {
      console.error("delete-account: auth admin deleteUser error:", delErr);
      return json({ error: "Impossibile completare l'eliminazione. Riprova o contatta il supporto." }, 500);
    }

    return json({ success: true });
  } catch (e) {
    console.error("delete-account error:", e);
    return json({ error: "Errore interno. Riprova più tardi." }, 500);
  }
});

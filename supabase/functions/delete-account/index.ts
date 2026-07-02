// Supabase Edge Function: "delete-account" — permette a un utente autenticato di eliminare
// definitivamente il proprio account e i propri dati.
//
// Sicurezza:
// - L'utente da eliminare NON è mai preso da un id passato dal client: withSupabase({auth:'user'})
//   verifica il JWT a livello di piattaforma e ci passa l'identità già accertata su ctx.userClaims.
//   Questo impedisce a un utente di eliminare l'account di un altro.
// - Richiede la password attuale nel body e la riverifica con signInWithPassword prima di
//   procedere: un token di sessione rubato (es. da un XSS) non basta da solo per eliminare
//   l'account. Questo passaggio passa anche attraverso l'eventuale hook anti brute-force
//   (Password Verification Hook) già configurato per il login.
// - Solo dopo la verifica si usa ctx.supabaseAdmin (service role, fornito automaticamente da
//   @supabase/server, mai esposto al client) per la pulizia dati e la cancellazione dell'utente.
//
// Limite noto: la pulizia dati è "best effort" sulle tabelle note al momento della scrittura
// (books, notes, votes, proposals, club_members, clubs, meetings, password_verification_attempts).
// Se in futuro aggiungi nuove tabelle con dati personali, aggiorna anche questa funzione.

import { withSupabase } from 'npm:@supabase/server@^1';

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

async function cleanupUserData(admin: any, uid: string) {
  // Ogni passo è indipendente e best-effort: un fallimento su una tabella non deve
  // bloccare la cancellazione delle altre né dell'account stesso.
  const safe = async (label: string, fn: () => Promise<unknown>) => {
    try { await fn(); } catch (e) { console.error(`delete-account cleanup [${label}] error:`, e); }
  };

  await safe('books', () => admin.from('books').delete().eq('user_id', uid));
  await safe('notes', () => admin.from('notes').delete().eq('user_id', uid));
  await safe('votes', () => admin.from('votes').delete().eq('user_id', uid));
  await safe('proposals', () => admin.from('proposals').delete().eq('user_id', uid));
  await safe('password_verification_attempts', () => admin.from('password_verification_attempts').delete().eq('user_id', uid));

  // Club di cui è owner: se ci sono altri membri, trasferisci la proprietà invece di
  // distruggere il club per tutti; se è l'unico membro, elimina il club e il suo contenuto.
  try {
    const { data: ownedClubs } = await admin.from('clubs').select('id').eq('owner', uid);
    for (const club of ownedClubs || []) {
      const { data: others } = await admin.from('club_members')
        .select('user_id,role').eq('club_id', club.id).neq('user_id', uid);
      if (others && others.length) {
        const newOwner = others.find((m: any) => m.role === 'admin') || others[0];
        await safe(`clubs.owner(${club.id})`, () => admin.from('clubs').update({ owner: newOwner.user_id }).eq('id', club.id));
        await safe(`meetings.created_by(${club.id})`, () => admin.from('meetings').update({ created_by: newOwner.user_id }).eq('club_id', club.id).eq('created_by', uid));
      } else {
        await safe(`meetings(${club.id})`, () => admin.from('meetings').delete().eq('club_id', club.id));
        await safe(`notes(${club.id})`, () => admin.from('notes').delete().eq('club_id', club.id));
        await safe(`proposals(${club.id})`, () => admin.from('proposals').delete().eq('club_id', club.id));
        await safe(`votes(${club.id})`, () => admin.from('votes').delete().eq('club_id', club.id));
        await safe(`club_members(${club.id})`, () => admin.from('club_members').delete().eq('club_id', club.id));
        await safe(`clubs(${club.id})`, () => admin.from('clubs').delete().eq('id', club.id));
      }
    }
  } catch (e) { console.error('delete-account cleanup [clubs] error:', e); }

  // Membership rimanenti (club di cui NON è owner) e profilo.
  await safe('club_members', () => admin.from('club_members').delete().eq('user_id', uid));
  await safe('profiles', () => admin.from('profiles').delete().eq('id', uid));
}

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method !== 'POST') return Response.json({ error: 'method not allowed' }, { status: 405 });

    const ip = req.headers.get('x-forwarded-for')?.split(',')[0].trim()
      || req.headers.get('cf-connecting-ip') || 'unknown';
    if (rateLimited(ip)) return Response.json({ error: 'Troppi tentativi. Riprova più tardi.' }, { status: 429 });

    let body: any;
    try { body = await req.json(); } catch { return Response.json({ error: 'JSON non valido.' }, { status: 400 }); }
    const password = typeof body?.password === 'string' ? body.password : '';
    if (!password) return Response.json({ error: "Password richiesta per confermare l'eliminazione." }, { status: 400 });

    // Identità accertata dalla piattaforma tramite il JWT, mai da un id fornito dal client.
    const uid = ctx.userClaims?.id;
    const email = ctx.userClaims?.email;
    if (!uid || !email) return Response.json({ error: 'Sessione non valida. Accedi di nuovo.' }, { status: 401 });

    // Riverifica la password (indipendente dal token di sessione già posseduto).
    const { error: pwErr } = await ctx.supabase.auth.signInWithPassword({ email, password });
    if (pwErr) return Response.json({ error: 'Password non corretta.' }, { status: 401 });

    // Pulizia dati applicativi + cancellazione dell'utente, con il client service-role
    // fornito automaticamente da @supabase/server (mai esposto al client).
    await cleanupUserData(ctx.supabaseAdmin, uid);
    const { error: delErr } = await ctx.supabaseAdmin.auth.admin.deleteUser(uid);
    if (delErr) {
      console.error('delete-account: auth admin deleteUser error:', delErr);
      return Response.json({ error: "Impossibile completare l'eliminazione. Riprova o contatta il supporto." }, { status: 500 });
    }

    return Response.json({ success: true });
  }),
};


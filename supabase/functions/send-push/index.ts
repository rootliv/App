// Supabase Edge Function: "send-push" — invia una notifica push Android (via Firebase
// Cloud Messaging) a un utente, leggendo i suoi token registrati in device_tokens.
//
// Chi la chiama: SOLO il trigger Postgres `notify_new_club_invite` (vedi migrazione
// 20260715_push_notifications.sql), mai il client web direttamente. La verifica JWT di
// piattaforma di Supabase richiede comunque un Authorization Bearer valido: il trigger
// passa la service_role key del progetto (mai esposta al sito pubblico).
//
// Configurazione richiesta (una tantum, vedi docs/NOTIFICHE_PUSH_SETUP.md):
// - Secret "FIREBASE_SERVICE_ACCOUNT" con il JSON dell'account di servizio Firebase
//   (Cloud Messaging). Senza questo secret la funzione risponde "ok" senza inviare nulla,
//   non genera errori che blocchino il resto dell'app.
//
// Limite attuale: solo Android. iOS richiede la capability "Push Notifications" in Xcode
// (non ancora configurata — vedi la nota su iOS lasciata in sospeso).

import { createClient } from 'npm:@supabase/supabase-js@2';
import { SignJWT, importPKCS8 } from 'npm:jose@5';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const key = await importPKCS8(sa.private_key, 'RS256');
  const jwt = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key);

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error('Scambio token OAuth Firebase fallito: ' + JSON.stringify(data));
  return data.access_token as string;
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });

    const { user_id, title, body } = await req.json();
    if (!user_id || !title) return new Response('Parametri mancanti (user_id, title)', { status: 400 });

    const saRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!saRaw) {
      // Non configurato: rispondiamo "ok" per non far fallire il trigger che ci ha
      // chiamato, semplicemente non inviamo nessuna notifica finche' non e' impostato.
      console.log('send-push: FIREBASE_SERVICE_ACCOUNT non configurato, nessun invio.');
      return new Response('ok (push non configurato)', { status: 200 });
    }
    const serviceAccount: ServiceAccount = JSON.parse(saRaw);

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data: tokens, error } = await admin
      .from('device_tokens')
      .select('token')
      .eq('user_id', user_id)
      .eq('platform', 'android');

    if (error) throw error;
    if (!tokens || !tokens.length) {
      return new Response('ok (nessun dispositivo Android registrato per questo utente)', { status: 200 });
    }

    const accessToken = await getAccessToken(serviceAccount);

    const results = await Promise.all(tokens.map(async (t: { token: string }) => {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: t.token,
              notification: { title, body: body || '' },
              android: { priority: 'high' },
            },
          }),
        }
      );
      if (!res.ok) console.error('send-push: invio FCM fallito per un token:', await res.text());
      return res.ok;
    }));

    return new Response(
      JSON.stringify({ sent: results.filter(Boolean).length, total: results.length }),
      { headers: { 'Content-Type': 'application/json' }, status: 200 }
    );
  } catch (e) {
    console.error('send-push: errore:', e);
    return new Response('Errore interno', { status: 500 });
  }
});

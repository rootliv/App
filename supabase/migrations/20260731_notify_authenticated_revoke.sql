-- ============================================================================
-- SICUREZZA: chiudere un dubbio concreto su chi può chiamare notify()
--
-- PERCHÉ
-- notify() è la funzione che scrive le notifiche E fa scattare le push (contiene la
-- service_role key incorporata nel proprio codice, necessaria per chiamare send-push).
-- Era stata resa non eseguibile da "public" e "anon", ma MAI esplicitamente da
-- "authenticated" (qualunque utente con un account, cioè chiunque usi l'app).
--
-- In PostgreSQL/Supabase, se "authenticated" avesse mai ricevuto l'esecuzione di questa
-- funzione anche solo attraverso i privilegi di default della piattaforma (un comportamento
-- documentato di Supabase per le funzioni nello schema public), un utente qualunque avrebbe
-- potuto chiamarla direttamente (supabase.rpc('notify', {...})) e far inviare una notifica
-- push con titolo/testo a piacere a QUALSIASI altro utente, aggirando completamente il
-- controllo aggiunto in precedenza dentro send-push (che quel controllo non vede, perché
-- la chiave service_role usata da notify() per chiamare send-push è già scritta dentro
-- notify() stessa).
--
-- Non è stato possibile verificare dal vivo lo stato attuale dei permessi sul database
-- (nessun accesso diretto disponibile in questa sessione): questa correzione chiude il
-- dubbio a prescindere, senza alcun costo — notify() non deve MAI essere chiamata
-- direttamente da un utente, solo dai trigger interni (che restano protetti: un trigger,
-- essendo esso stesso SECURITY DEFINER, non dipende dai permessi dell'utente che lo fa
-- scattare per poter chiamare notify() al suo interno).
--
-- Approfitto anche per ripulire tre funzioni ormai "orfane" (i vecchi trigger dedicati
-- solo alla push, sostituiti dal sistema unificato): erano dichiarate come funzioni
-- trigger (returns trigger), quindi Supabase non le espone comunque come chiamabili
-- direttamente — rischio basso, ma è comunque più pulito toglierle del tutto, contenevano
-- anch'esse la service_role key incorporata.
--
-- Idempotente: si può rilanciare senza danni.
-- ============================================================================

revoke all on function public.notify(uuid,text,text,text,bigint,uuid,text) from public, anon, authenticated;

-- I trigger interni continuano a funzionare: girano come SECURITY DEFINER con i privilegi
-- di chi li ha creati, non con quelli dell'utente che ha generato l'evento — questa
-- revoca non li tocca.

-- Pulizia delle funzioni orfane (sostituite dal sistema di notifiche unificato in
-- 20260724_unify_notifications_push.sql): i loro trigger erano già stati disattivati,
-- ora rimuoviamo anche le funzioni stesse, che non servono più a nulla.
drop function if exists public.notify_new_club_invite() cascade;
drop function if exists public.notify_new_book_chosen() cascade;
drop function if exists public.notify_new_note() cascade;

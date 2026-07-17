-- ----------------------------------------------------------------------------
-- FIX: le librerie pubbliche non erano più visibili a chi segue il lettore.
--
-- CAUSA
-- La migrazione 20260712_security_phase1 ha chiuso la tabella `profiles`
-- (policy `profiles_self_read`: ognuno legge SOLO la propria riga), per sanare
-- una fuga reale di email. Sono stati adattati tutti i punti del client, ma è
-- rimasta indietro la policy `books_read_public` (introdotta in 20260707_social),
-- che per decidere la visibilità legge il profilo ALTRUI dentro una sottoquery:
--
--     exists (select 1 from public.profiles p
--             where p.id = books.user_id and p.public_library = true)
--
-- In PostgreSQL le sottoquery dentro l'espressione di una policy sono soggette
-- alla RLS della tabella referenziata. Con `profiles_self_read` quella EXISTS è
-- sempre falsa per un utente diverso da noi: il ramo "libreria pubblica E la
-- segui" non può mai essere vero, quindi NESSUN libro altrui è mai visibile.
-- Sintomo nell'app: "Questa libreria è vuota o privata" anche per librerie
-- pubbliche e regolarmente seguite.
--
-- SOLUZIONE
-- Una funzione SECURITY DEFINER che risponde a UNA sola domanda booleana:
-- "la libreria di questo utente è pubblica?". Essendo SECURITY DEFINER non è
-- soggetta alla RLS di `profiles`, quindi la policy può di nuovo verificarlo.
-- È lo stesso schema già usato altrove nel progetto (is_username_taken,
-- club_member_read_book): search_path fissato e grant minimi.
--
-- LA SICUREZZA NON CAMBIA
-- - La funzione restituisce solo `true`/`false`: non espone email, nome, dati.
-- - La condizione resta identica: libreria pubblica **E** relazione di follow.
-- - Il controllo "la segui" continua a passare dalla RLS di `follows`.
-- - `profiles` resta chiusa: l'email non è leggibile da nessun altro.
--
-- Idempotente: si può rieseguire senza rischi.
-- ----------------------------------------------------------------------------

-- 1) La domanda booleana, isolata e senza dati sensibili in uscita.
create or replace function public.library_is_public(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(p.public_library, false)
  from public.profiles p
  where p.id = p_uid;
$$;

-- Grant minimi: solo chi è autenticato, mai anon/public.
revoke all on function public.library_is_public(uuid) from public, anon;
grant execute on function public.library_is_public(uuid) to authenticated;

-- 2) La policy torna a funzionare: stessa regola di prima, ma la verifica
--    "è pubblica?" passa dalla funzione invece che dalla tabella chiusa.
drop policy if exists books_read_public on public.books;
create policy books_read_public on public.books
  for select using (
    auth.uid() = user_id
    OR (
      public.library_is_public(books.user_id)
      AND exists (
        select 1 from public.follows f
        where f.followed_id = books.user_id
          and f.follower_id = auth.uid()
      )
    )
  );

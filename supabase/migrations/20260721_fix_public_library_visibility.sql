-- ----------------------------------------------------------------------------
-- FIX: le librerie pubbliche non erano più visibili a chi segue il lettore.
--
-- CAUSA (ricostruita e riprodotta su PostgreSQL 16)
-- La policy `books_read_public` (20260707_social) per decidere la visibilità
-- legge il profilo ALTRUI dentro una sottoquery:
--
--     exists (select 1 from public.profiles p
--             where p.id = books.user_id and p.public_library = true)
--
-- In PostgreSQL le sottoquery dentro l'espressione di una policy sono soggette
-- alla RLS della tabella referenziata. Finché su `profiles` è sopravvissuta la
-- vecchia regola permissiva "profili: leggi tutti" (using true), quella EXISTS
-- funzionava e le librerie pubbliche si vedevano: reggeva per caso, appoggiata
-- proprio alla regola che perdeva le email.
--
-- La FASE 2 (20260718_security_phase2, eseguita il 16/07) ha giustamente tolto
-- "profili: leggi tutti". Da quel momento vale solo `profiles_self_read`
-- (auth.uid() = id): la sottoquery non trova più il profilo altrui, la EXISTS è
-- sempre falsa e il ramo "libreria pubblica E la segui" non può mai avverarsi.
-- Risultato: NESSUN libro altrui è più visibile, nemmeno per librerie pubbliche
-- regolarmente seguite. Sintomo nell'app: "Questa libreria è vuota o privata".
--
-- Verificato su PostgreSQL 16 riproducendo la sequenza reale:
--   dopo Fase 1 -> 3 libri visibili | dopo Fase 2 -> 0 | con questo fix -> 3,
--   con le email altrui sempre illeggibili (0 righe) in tutti e tre i casi.
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

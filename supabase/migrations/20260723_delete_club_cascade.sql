-- ============================================================================
-- CANCELLAZIONE CLUB, GARANTITA PER TUTTI I MEMBRI
--
-- PERCHÉ
-- Il codice dell'app cancellava membri/incontri/proposte/note/club uno per uno,
-- dal client. Se anche solo UNA di quelle tabelle non permette (per le regole di
-- sicurezza, RLS) che l'amministratore cancelli righe di ALTRI utenti, quel passo
-- fallisce in silenzio: il club poteva sparire per l'amministratore ma restare
-- visibile agli altri membri.
--
-- COSA FA QUESTA MIGRATION
-- Una funzione unica, eseguita LATO SERVER, che:
--  1) verifica che chi chiama sia DAVVERO l'amministratore del club (altrimenti si
--     ferma con un errore chiaro);
--  2) cancella esplicitamente OGNI riga collegata al club, per QUALSIASI utente
--     coinvolto (membri, inviti, incontri, proposte, voti, note del diario,
--     notifiche, posizioni di lettura), senza dipendere dalle policy RLS delle
--     singole tabelle: dopo il controllo di sicurezza al punto 1, opera con i
--     privilegi del proprietario della funzione;
--  3) cancella infine il club stesso.
--
-- Idempotente: si può rilanciare senza danni.
-- ============================================================================

create or replace function public.delete_club_cascade(p_club_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Solo l'amministratore (owner) del club può eliminarlo.
  if not exists (select 1 from public.clubs where id = p_club_id and owner = auth.uid()) then
    raise exception 'Solo l''amministratore può eliminare il club.';
  end if;

  -- Cancellazione esplicita di TUTTO ciò che è collegato, per ogni membro coinvolto.
  -- Non ci affidiamo alle cascate automatiche delle chiavi esterne: qui le
  -- garantiamo direttamente, a prescindere da come sono configurate.
  delete from public.votes            where club_id = p_club_id;
  delete from public.proposals        where club_id = p_club_id;
  delete from public.meetings         where club_id = p_club_id;
  delete from public.notes            where club_id = p_club_id;
  delete from public.club_invites     where club_id = p_club_id;
  delete from public.reading_progress where club_id = p_club_id;
  delete from public.notifications    where club_id = p_club_id;
  delete from public.club_members     where club_id = p_club_id;

  delete from public.clubs where id = p_club_id;
end;
$$;

-- Eseguibile solo da utenti autenticati (la funzione stessa verifica che sia l'admin).
revoke all on function public.delete_club_cascade(bigint) from public, anon;
grant execute on function public.delete_club_cascade(bigint) to authenticated;

-- ============================================================================
-- Restringe agli admin le azioni di "sorteggio/votazione" del club, lasciando
-- invece aperte a tutti i membri le modifiche già decise in precedenza
-- (immagine e descrizione del club).
--
-- Perché serve: la policy clubs_update_members (20260706_club_image.sql)
-- permette a QUALSIASI membro di aggiornare la riga del club, senza
-- distinguere quali colonne sta cambiando. Le funzioni dell'app che avviano/
-- annullano/chiudono il sorteggio o la votazione erano già nascoste in
-- interfaccia ai soli admin, ma un membro poteva comunque chiamarle a mano
-- (es. dalla console del browser) perché il database non lo impediva.
--
-- Regola scelta: solo l'admin/owner del club PUÒ modificare selection_mode,
-- current_chooser, current_title/author/cover, cycle_choosers — TRANNE per
-- chi in quel momento è il "chooser" di turno nel sorteggio (deve poter
-- scegliere il libro quando tocca a lui: è l'unico caso in cui un membro
-- normale scrive legittimamente su questi campi). Immagine e descrizione
-- restano modificabili da tutti i membri, invariato.
--
-- Sicura da rilanciare più volte (idempotente).
-- ============================================================================

create or replace function public.clubs_enforce_admin_only_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_admin boolean;
  v_is_current_chooser boolean;
begin
  v_is_admin := (auth.uid() = new.owner) or exists (
    select 1 from public.club_members
    where club_id = new.id and user_id = auth.uid() and role = 'admin'
  );

  v_is_current_chooser := (old.current_chooser is not null and old.current_chooser = auth.uid());

  if not v_is_admin and not v_is_current_chooser then
    if new.selection_mode is distinct from old.selection_mode
      or new.current_chooser is distinct from old.current_chooser
      or new.current_title is distinct from old.current_title
      or new.current_author is distinct from old.current_author
      or new.current_cover is distinct from old.current_cover
      or new.cycle_choosers is distinct from old.cycle_choosers
    then
      raise exception 'Solo l''amministratore del club (o chi ha il turno per scegliere) può modificare la selezione del libro, il sorteggio o la votazione.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists clubs_admin_only_fields on public.clubs;
create trigger clubs_admin_only_fields
  before update on public.clubs
  for each row
  execute function public.clubs_enforce_admin_only_fields();

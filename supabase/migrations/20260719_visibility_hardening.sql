-- ============================================================================
-- Chiude i due varchi minori rimasti dalla fotografia delle regole (pg_policies):
-- l'elenco membri di un club e gli incontri erano leggibili da QUALSIASI
-- utente autenticato, anche di club a cui non appartiene. Li restringo a chi
-- è davvero membro del club in questione, con lo stesso schema già usato (e
-- già funzionante) per gli inviti ai club (club_invites_insert).
--
-- Sicura da rilanciare più volte (idempotente).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) CLUB_MEMBERS: "membri: leggi se autenticato" permetteva a chiunque avesse
--    un account di vedere l'elenco membri di QUALSIASI club, non solo dei
--    propri. Ora serve essere membri di quello specifico club.
-- ----------------------------------------------------------------------------
drop policy if exists "membri: leggi se autenticato" on public.club_members;

create policy club_members_select_same_club on public.club_members
  for select using (
    exists (
      select 1 from public.club_members m2
      where m2.club_id = club_members.club_id and m2.user_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- 2) MEETINGS (incontri): "incontri: crea" permetteva a chiunque autenticato
--    di inserire un incontro in QUALSIASI club (anche non suo) e con
--    created_by falsificato a piacere; "incontri: leggi" permetteva a
--    chiunque di leggere data/luogo degli incontri di club altrui.
-- ----------------------------------------------------------------------------
drop policy if exists "incontri: crea" on public.meetings;

create policy meetings_insert_own_club_member on public.meetings
  for insert with check (
    auth.uid() = created_by
    and exists (
      select 1 from public.club_members m
      where m.club_id = meetings.club_id and m.user_id = auth.uid()
    )
  );

drop policy if exists "incontri: leggi" on public.meetings;

create policy meetings_select_club_member on public.meetings
  for select using (
    exists (
      select 1 from public.club_members m
      where m.club_id = meetings.club_id and m.user_id = auth.uid()
    )
  );

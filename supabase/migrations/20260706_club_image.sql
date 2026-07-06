-- Aggiunge la foto del club (immagine ridimensionata salvata come data URL base64).
-- Ogni membro del club può cambiarla dall'app.
alter table public.clubs add column if not exists image text;

-- Permetti ai MEMBRI del club di aggiornare image e description (non solo all'owner).
-- Nota: adatta il nome della policy se ne hai già una di UPDATE sui club.
drop policy if exists clubs_update_members on public.clubs;
create policy clubs_update_members on public.clubs
  for update
  using (
    auth.uid() = owner
    OR exists (select 1 from public.club_members m where m.club_id = clubs.id and m.user_id = auth.uid())
  )
  with check (
    auth.uid() = owner
    OR exists (select 1 from public.club_members m where m.club_id = clubs.id and m.user_id = auth.uid())
  );

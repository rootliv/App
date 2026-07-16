-- Impedisce a un utente di comparire due volte come membro dello stesso club.
-- Prima non c'era nessun vincolo: un doppio tocco su "Unisciti" (con codice) o su "Accetta"
-- invito poteva inserire due righe identiche in club_members, facendo comparire lo stesso
-- lettore due volte nella lista membri e gonfiando il conteggio "N membri".
--
-- Passo 1: ripulisco eventuali duplicati già presenti, tenendo per ciascuna coppia
-- (club_id, user_id) una sola riga — quella con ruolo 'admin' se esiste, altrimenti la più vecchia.
with ranked as (
  select
    ctid,
    row_number() over (
      partition by club_id, user_id
      order by (role = 'admin') desc, ctid asc
    ) as rn
  from public.club_members
)
delete from public.club_members cm
using ranked
where cm.ctid = ranked.ctid
  and ranked.rn > 1;

-- Passo 2: da qui in avanti il database stesso rifiuta un secondo inserimento identico.
alter table public.club_members
  add constraint club_members_club_user_unique unique (club_id, user_id);

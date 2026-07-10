-- Funzione: verifica se qualche MEMBRO del club ha già letto (status='read') un libro con quel titolo.
-- SECURITY DEFINER così può leggere i libri dei membri aggirando la RLS in modo controllato,
-- ma restituisce solo il nome del lettore e nulla di sensibile.
create or replace function public.club_member_read_book(p_club_id bigint, p_title text)
returns table(reader_name text)
language sql
security definer
set search_path = public
as $$
  select coalesce(pr.name, pr.username, 'un membro') as reader_name
  from public.club_members m
  join public.books b on b.user_id = m.user_id
  left join public.profiles pr on pr.id = m.user_id
  where m.club_id = p_club_id
    and b.status = 'read'
    and lower(trim(b.title)) = lower(trim(p_title))
  limit 1;
$$;

-- Permetti a chi è autenticato di chiamarla (la funzione controlla comunque il club).
grant execute on function public.club_member_read_book(bigint, text) to authenticated;

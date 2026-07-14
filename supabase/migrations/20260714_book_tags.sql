-- Categorie e tag personali per ogni libro (etichette libere scelte dal lettore).
-- Il genere resta separato e viene rilevato automaticamente da Wikidata.
-- I tag sono salvati come stringa JSON (es. ["Università","Da rileggere"]).
alter table public.books add column if not exists tags text;

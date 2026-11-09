-- Estado de cumplimiento por ocurrencia de cada compromiso de agenda.
-- Las claves JSON son fechas locales yyyy-MM-dd; los valores indican si se realizó.
alter table public.eventos_agenda
  add column if not exists cumplimientos jsonb not null default '{}'::jsonb;

update public.eventos_agenda
set cumplimientos = '{}'::jsonb
where cumplimientos is null;

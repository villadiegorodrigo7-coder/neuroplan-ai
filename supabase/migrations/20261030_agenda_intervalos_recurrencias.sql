-- Migración de agenda: hora de cierre y recurrencias.
-- Ejecutar una sola vez en Supabase > SQL Editor antes de instalar la nueva APK.

alter table public.eventos_agenda
  add column if not exists fecha_fin timestamptz,
  add column if not exists frecuencia text not null default 'unica',
  add column if not exists dias_semana integer[] not null default '{}';

-- Los compromisos antiguos tenían una sola hora. Se conservan y se les
-- asigna una duración inicial de una hora para que sigan siendo válidos.
update public.eventos_agenda
set fecha_fin = fecha + interval '1 hour'
where fecha_fin is null;

alter table public.eventos_agenda
  alter column fecha_fin set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'eventos_agenda_frecuencia_check'
      and conrelid = 'public.eventos_agenda'::regclass
  ) then
    alter table public.eventos_agenda
      add constraint eventos_agenda_frecuencia_check
      check (frecuencia in ('unica', 'diaria', 'semanal', 'personalizada'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'eventos_agenda_dias_semana_check'
      and conrelid = 'public.eventos_agenda'::regclass
  ) then
    alter table public.eventos_agenda
      add constraint eventos_agenda_dias_semana_check
      check (dias_semana <@ array[1,2,3,4,5,6,7]::integer[]);
  end if;
end $$;

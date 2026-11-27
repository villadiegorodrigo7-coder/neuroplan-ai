create table public.historial_rueda (
  user_id uuid not null references auth.users (id) on delete cascade,
  id text not null,
  pilar text not null check (char_length(btrim(pilar)) between 1 and 100),
  registrado_en timestamptz not null default now(),
  tipo text not null check (tipo in ('inicio', 'valoracion', 'avance')),
  valor smallint check (valor between 0 and 10),
  nota text not null default '' check (char_length(nota) <= 500),
  ciclo_id text,
  primary key (user_id, id),
  constraint historial_rueda_contenido_check check (
    (tipo in ('inicio', 'valoracion') and valor is not null and nota = '')
    or (tipo = 'avance' and valor is null and char_length(btrim(nota)) > 0)
  ),
  constraint historial_rueda_inicio_id_check check (
    (tipo = 'inicio' and id = 'inicio:' || pilar)
    or (tipo <> 'inicio' and id not like 'inicio:%')
  )
);

alter table public.historial_rueda enable row level security;

revoke all on table public.historial_rueda from public, anon, authenticated;
grant select, insert on table public.historial_rueda to authenticated;

create policy "Leer los registros propios de la rueda"
  on public.historial_rueda
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy "Agregar registros propios de la rueda"
  on public.historial_rueda
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create table if not exists public.historial_actividades (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  origen text not null check (origen in ('agenda', 'habito')),
  origen_id text not null,
  titulo text not null,
  accion text not null,
  fecha date not null,
  bloque text,
  detalles jsonb not null default '{}'::jsonb,
  creado_en timestamptz not null default now()
);

create index if not exists historial_actividades_usuario_fecha_idx
  on public.historial_actividades (user_id, fecha);

alter table public.historial_actividades enable row level security;

drop policy if exists "Users can read own activity history" on public.historial_actividades;
create policy "Users can read own activity history"
  on public.historial_actividades for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own activity history" on public.historial_actividades;
create policy "Users can insert own activity history"
  on public.historial_actividades for insert
  with check (auth.uid() = user_id);

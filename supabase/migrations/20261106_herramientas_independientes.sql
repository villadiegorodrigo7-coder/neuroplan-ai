-- Almacenamiento independiente para las herramientas activas de NEUROPLAN.
-- No modifica ni elimina la tabla heredada public.cuadernillos.

create table if not exists public.neuroplan_herramientas (
  user_id uuid primary key references auth.users(id) on delete cascade,
  datos jsonb not null default '{}'::jsonb,
  actualizada_en timestamptz not null default now()
);

alter table public.neuroplan_herramientas enable row level security;

drop policy if exists "Cada usuario gestiona sus herramientas" on public.neuroplan_herramientas;
create policy "Cada usuario gestiona sus herramientas"
  on public.neuroplan_herramientas
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update, delete
  on public.neuroplan_herramientas to authenticated;

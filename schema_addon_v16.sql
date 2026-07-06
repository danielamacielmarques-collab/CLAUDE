-- ============================================================
-- NID/COBEN Agile Board v16 — ADDON
-- Plano de Ação COBEN (Gestão de Benefício) — estado e vínculos
-- ============================================================
-- Execute APÓS o schema_addon_v15.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

-- Estado mutável de cada subação do Plano de Ação (catálogo fixo no app: PA_GB).
-- pa_idx = índice estável (0..61) da subação no catálogo embutido.
create table if not exists pa_items (
  id           uuid primary key default gen_random_uuid(),
  pa_idx       integer not null unique,
  status       text,                         -- override do status; null = usa o do catálogo
  sprint_id    integer,                      -- sprint em que foi encaixada
  vinculo_tipo text check (vinculo_tipo in ('entrega','tarefa') or vinculo_tipo is null),
  entrega_ref  text,                         -- 'sid-idx' quando vinculada a uma entrega da sprint
  tarefa_id    uuid references subtarefas(id) on delete set null,
  obs          text,
  updated_at   timestamptz default now()
);

create index if not exists idx_pa_items_sprint on pa_items(sprint_id);

drop trigger if exists t_pa_upd on pa_items;
create trigger t_pa_upd before update on pa_items
  for each row execute function set_updated_at();

alter table pa_items enable row level security;
drop policy if exists pa_items_read  on pa_items;
drop policy if exists pa_items_write on pa_items;
create policy pa_items_read  on pa_items for select using (auth.role() = 'authenticated');
create policy pa_items_write on pa_items for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

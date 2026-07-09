-- ============================================================
-- NID/COBEN Agile Board v18 — ADDON
-- Auditoria — Plano de Ação de Auditoria (estado e vínculos)
-- ============================================================
-- Execute APÓS o schema_addon_v17.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

-- Estado mutável de cada ação do Plano de Ação de Auditoria
-- (catálogo fixo no app: AUDIT_GB).
-- audit_idx = índice estável da ação no catálogo embutido.
create table if not exists audit_items (
  id           uuid primary key default gen_random_uuid(),
  audit_idx    integer not null unique,
  status       text,                         -- override do status; null = usa o do catálogo
  sprint_id    integer,                      -- sprint em que foi encaixada
  vinculo_tipo text check (vinculo_tipo in ('entrega','tarefa') or vinculo_tipo is null),
  entrega_ref  text,                         -- 'sid-idx' quando vinculada a uma entrega da sprint
  tarefa_id    uuid references subtarefas(id) on delete set null,
  obs          text,
  updated_at   timestamptz default now()
);

create index if not exists idx_audit_items_sprint on audit_items(sprint_id);

drop trigger if exists t_audit_upd on audit_items;
create trigger t_audit_upd before update on audit_items
  for each row execute function set_updated_at();

alter table audit_items enable row level security;
drop policy if exists audit_items_read  on audit_items;
drop policy if exists audit_items_write on audit_items;
create policy audit_items_read  on audit_items for select using (auth.role() = 'authenticated');
create policy audit_items_write on audit_items for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

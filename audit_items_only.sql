-- Rode este bloco no SQL Editor do Supabase para habilitar a aba Auditoria.
-- Cria apenas a tabela audit_items (estado/vinculos das acoes de auditoria).
-- Idempotente: pode rodar mais de uma vez sem problema.

create table if not exists audit_items (
  id           uuid primary key default gen_random_uuid(),
  audit_idx    integer not null unique,
  status       text,
  sprint_id    integer,
  vinculo_tipo text check (vinculo_tipo in ('entrega','tarefa') or vinculo_tipo is null),
  entrega_ref  text,
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

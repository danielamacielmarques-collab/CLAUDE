-- ============================================================
-- NID/COBEN Agile Board v17 — ADDON
-- Ideias & Aprendizado: projetos embrionários, cursos, workshops
-- ============================================================
-- Execute APÓS o schema_addon_v16.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

create table if not exists ideias (
  id          uuid primary key default gen_random_uuid(),
  tipo        text not null default 'ideia'
              check (tipo in ('ideia','embrionario','curso','workshop')),
  titulo      text not null,
  descricao   text,
  link        text,
  tags_text   text,
  status      text not null default 'rascunho'
              check (status in ('rascunho','compartilhado','em_avaliacao','aprovado','arquivado')),
  autor_id    uuid references profiles(id) on delete set null,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

create index if not exists idx_ideias_tipo on ideias(tipo);
create index if not exists idx_ideias_status on ideias(status);

drop trigger if exists t_ideias_upd on ideias;
create trigger t_ideias_upd before update on ideias
  for each row execute function set_updated_at();

alter table ideias enable row level security;
drop policy if exists ideias_read  on ideias;
drop policy if exists ideias_write on ideias;
create policy ideias_read  on ideias for select using (auth.role() = 'authenticated');
create policy ideias_write on ideias for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Anexos em ideias (reusa a tabela task_attachments com coluna ideia_id)
alter table task_attachments add column if not exists ideia_id uuid references ideias(id) on delete cascade;
create index if not exists idx_task_attachments_ideia on task_attachments(ideia_id);

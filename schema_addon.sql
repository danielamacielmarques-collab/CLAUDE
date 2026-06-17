-- ============================================================
-- NID/COBEN Agile Board v5 — ADDON: Comentários e Anexos
-- ============================================================
-- Execute APÓS o schema.sql principal (já existente)
-- Esta migração é idempotente: pode ser executada várias vezes
-- ============================================================

-- =====================================================
-- COMENTÁRIOS POR TAREFA
-- =====================================================
create table if not exists task_comments (
  id          uuid primary key default gen_random_uuid(),
  tarefa_id   uuid references subtarefas(id) on delete cascade,
  profile_id  uuid references profiles(id)   on delete set null,
  texto       text not null,
  created_at  timestamptz default now()
);
create index if not exists idx_task_comments_tarefa on task_comments(tarefa_id);

-- =====================================================
-- ANEXOS POR TAREFA
-- =====================================================
create table if not exists task_attachments (
  id          uuid primary key default gen_random_uuid(),
  tarefa_id   uuid references subtarefas(id) on delete cascade,
  profile_id  uuid references profiles(id)   on delete set null,
  nome        text not null,
  storage_path text not null,
  url         text not null,
  mime        text,
  tamanho     bigint,
  created_at  timestamptz default now()
);
create index if not exists idx_task_attachments_tarefa on task_attachments(tarefa_id);

-- =====================================================
-- RLS — leitura/escrita autenticada
-- =====================================================
alter table task_comments    enable row level security;
alter table task_attachments enable row level security;

drop policy if exists task_comments_read    on task_comments;
drop policy if exists task_comments_write   on task_comments;
drop policy if exists task_attachments_read on task_attachments;
drop policy if exists task_attachments_write on task_attachments;

create policy task_comments_read     on task_comments    for select using (auth.role() = 'authenticated');
create policy task_comments_write    on task_comments    for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy task_attachments_read  on task_attachments for select using (auth.role() = 'authenticated');
create policy task_attachments_write on task_attachments for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- =====================================================
-- STORAGE BUCKET — task-files
-- =====================================================
-- Cria o bucket público pra anexos
insert into storage.buckets (id, name, public)
  values ('task-files', 'task-files', true)
  on conflict (id) do update set public = true;

-- Políticas de Storage: qualquer usuário autenticado pode upload/list/delete
drop policy if exists "task_files_select" on storage.objects;
drop policy if exists "task_files_insert" on storage.objects;
drop policy if exists "task_files_update" on storage.objects;
drop policy if exists "task_files_delete" on storage.objects;

create policy "task_files_select" on storage.objects for select
  using (bucket_id = 'task-files');
create policy "task_files_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'task-files');
create policy "task_files_update" on storage.objects for update to authenticated
  using (bucket_id = 'task-files');
create policy "task_files_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'task-files');

-- ============================================================
-- NID/COBEN Agile Board v6 — ADDON
-- Comentários, Anexos, Checklist, Tags em ENTREGAS (não só tarefas)
-- Campos extras nas entregas: prioridade, fase, story points, progresso
-- ============================================================
-- Execute APÓS o schema.sql principal.
-- Esta migração é idempotente: pode ser executada várias vezes.
-- Inclui também o conteúdo do schema_addon.sql v5 (comentários e anexos).
-- ============================================================

-- =====================================================
-- SPRINT_ENTREGAS — colunas extras
-- =====================================================
alter table sprint_entregas add column if not exists descricao    text;
alter table sprint_entregas add column if not exists prioridade   text default 'media';
alter table sprint_entregas add column if not exists fase         text default 'execucao';
alter table sprint_entregas add column if not exists story_points integer;
alter table sprint_entregas add column if not exists progresso    integer default 0;
alter table sprint_entregas add column if not exists data_inicio  date;

-- =====================================================
-- COMENTÁRIOS (vincula a tarefa OU entrega)
-- =====================================================
create table if not exists task_comments (
  id          uuid primary key default gen_random_uuid(),
  tarefa_id   uuid references subtarefas(id) on delete cascade,
  sprint_id   integer,
  entrega_idx integer,
  profile_id  uuid references profiles(id) on delete set null,
  texto       text not null,
  created_at  timestamptz default now()
);
alter table task_comments alter column tarefa_id drop not null;
alter table task_comments add column if not exists sprint_id   integer;
alter table task_comments add column if not exists entrega_idx integer;
create index if not exists idx_task_comments_tarefa  on task_comments(tarefa_id);
create index if not exists idx_task_comments_entrega on task_comments(sprint_id, entrega_idx);

-- =====================================================
-- ANEXOS (vincula a tarefa OU entrega)
-- =====================================================
create table if not exists task_attachments (
  id           uuid primary key default gen_random_uuid(),
  tarefa_id    uuid references subtarefas(id) on delete cascade,
  sprint_id    integer,
  entrega_idx  integer,
  profile_id   uuid references profiles(id) on delete set null,
  nome         text not null,
  storage_path text not null,
  url          text not null,
  mime         text,
  tamanho      bigint,
  created_at   timestamptz default now()
);
alter table task_attachments alter column tarefa_id drop not null;
alter table task_attachments add column if not exists sprint_id   integer;
alter table task_attachments add column if not exists entrega_idx integer;
create index if not exists idx_task_attachments_tarefa  on task_attachments(tarefa_id);
create index if not exists idx_task_attachments_entrega on task_attachments(sprint_id, entrega_idx);

-- =====================================================
-- CHECKLIST — tarefa OU entrega
-- =====================================================
alter table checklist_items alter column tarefa_id drop not null;
alter table checklist_items add column if not exists sprint_id   integer;
alter table checklist_items add column if not exists entrega_idx integer;
create index if not exists idx_checklist_entrega on checklist_items(sprint_id, entrega_idx);

-- =====================================================
-- TAGS — tarefa OU entrega
-- =====================================================
alter table task_tags alter column tarefa_id drop not null;
alter table task_tags add column if not exists sprint_id   integer;
alter table task_tags add column if not exists entrega_idx integer;
create index if not exists idx_task_tags_entrega on task_tags(sprint_id, entrega_idx);

-- =====================================================
-- RLS
-- =====================================================
alter table task_comments    enable row level security;
alter table task_attachments enable row level security;

drop policy if exists task_comments_read     on task_comments;
drop policy if exists task_comments_write    on task_comments;
drop policy if exists task_attachments_read  on task_attachments;
drop policy if exists task_attachments_write on task_attachments;

create policy task_comments_read     on task_comments    for select using (auth.role() = 'authenticated');
create policy task_comments_write    on task_comments    for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy task_attachments_read  on task_attachments for select using (auth.role() = 'authenticated');
create policy task_attachments_write on task_attachments for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- =====================================================
-- STORAGE BUCKET — task-files
-- =====================================================
insert into storage.buckets (id, name, public)
  values ('task-files', 'task-files', true)
  on conflict (id) do update set public = true;

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

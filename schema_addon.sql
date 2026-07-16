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
alter table task_comments add column if not exists evento_id   uuid references calendar_events(id) on delete cascade;
alter table task_comments add column if not exists evento_data date;
alter table task_comments add column if not exists pa_idx      integer;
alter table task_comments add column if not exists audit_idx   integer;
create index if not exists idx_task_comments_tarefa      on task_comments(tarefa_id);
create index if not exists idx_task_comments_entrega     on task_comments(sprint_id, entrega_idx);
create index if not exists idx_task_comments_evento      on task_comments(evento_id);
create index if not exists idx_task_comments_evento_data on task_comments(evento_id, evento_data);
create index if not exists idx_task_comments_pa          on task_comments(pa_idx);
create index if not exists idx_task_comments_audit       on task_comments(audit_idx);

-- =====================================================
-- IDEIAS & APRENDIZADO
-- =====================================================
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
create index if not exists idx_ideias_tipo   on ideias(tipo);
create index if not exists idx_ideias_status on ideias(status);

alter table ideias enable row level security;
drop policy if exists ideias_read  on ideias;
drop policy if exists ideias_write on ideias;
create policy ideias_read  on ideias for select using (auth.role() = 'authenticated');
create policy ideias_write on ideias for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- =====================================================
-- ANEXOS (vincula a tarefa OU entrega OU evento OU ideia)
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
alter table task_attachments add column if not exists evento_id   uuid references calendar_events(id) on delete cascade;
alter table task_attachments add column if not exists evento_data date;
alter table task_attachments add column if not exists ideia_id    uuid references ideias(id) on delete cascade;
alter table task_attachments add column if not exists pa_idx      integer;
alter table task_attachments add column if not exists audit_idx   integer;
create index if not exists idx_task_attachments_tarefa      on task_attachments(tarefa_id);
create index if not exists idx_task_attachments_entrega     on task_attachments(sprint_id, entrega_idx);
create index if not exists idx_task_attachments_evento      on task_attachments(evento_id);
create index if not exists idx_task_attachments_evento_data on task_attachments(evento_id, evento_data);
create index if not exists idx_task_attachments_ideia       on task_attachments(ideia_id);
create index if not exists idx_task_attachments_pa          on task_attachments(pa_idx);
create index if not exists idx_task_attachments_audit       on task_attachments(audit_idx);

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

-- =====================================================
-- PLANO DE AÇÃO — estado/vínculos das subações (catálogo PA_GB no app)
-- =====================================================
create table if not exists pa_items (
  id           uuid primary key default gen_random_uuid(),
  pa_idx       integer not null unique,
  status       text,
  sprint_id    integer,
  vinculo_tipo text check (vinculo_tipo in ('entrega','tarefa') or vinculo_tipo is null),
  entrega_ref  text,
  tarefa_id    uuid references subtarefas(id) on delete set null,
  obs          text,
  oculto       boolean default false,
  novo_prazo   date,
  prazo_motivo text,
  updated_at   timestamptz default now()
);
alter table pa_items add column if not exists oculto       boolean default false;
alter table pa_items add column if not exists novo_prazo   date;
alter table pa_items add column if not exists prazo_motivo text;
create index if not exists idx_pa_items_sprint on pa_items(sprint_id);
drop trigger if exists t_pa_upd on pa_items;
create trigger t_pa_upd before update on pa_items
  for each row execute function set_updated_at();
alter table pa_items enable row level security;
drop policy if exists pa_items_read  on pa_items;
drop policy if exists pa_items_write on pa_items;
create policy pa_items_read  on pa_items for select using (auth.role() = 'authenticated');
create policy pa_items_write on pa_items for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- =====================================================
-- AUDITORIA — estado/vínculos das ações de auditoria (catálogo AUDIT_GB no app)
-- =====================================================
create table if not exists audit_items (
  id           uuid primary key default gen_random_uuid(),
  audit_idx    integer not null unique,
  status       text,
  sprint_id    integer,
  vinculo_tipo text check (vinculo_tipo in ('entrega','tarefa') or vinculo_tipo is null),
  entrega_ref  text,
  tarefa_id    uuid references subtarefas(id) on delete set null,
  obs          text,
  oculto       boolean default false,
  novo_prazo   date,
  prazo_motivo text,
  updated_at   timestamptz default now()
);
alter table audit_items add column if not exists oculto       boolean default false;
alter table audit_items add column if not exists novo_prazo   date;
alter table audit_items add column if not exists prazo_motivo text;
create index if not exists idx_audit_items_sprint on audit_items(sprint_id);
drop trigger if exists t_audit_upd on audit_items;
create trigger t_audit_upd before update on audit_items
  for each row execute function set_updated_at();
alter table audit_items enable row level security;
drop policy if exists audit_items_read  on audit_items;
drop policy if exists audit_items_write on audit_items;
create policy audit_items_read  on audit_items for select using (auth.role() = 'authenticated');
create policy audit_items_write on audit_items for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- =====================================================
-- GIROS DA SEMANA salvos (com edição estruturada em JSON)
-- =====================================================
create table if not exists giros (
  id             uuid primary key default gen_random_uuid(),
  periodo_inicio date,
  periodo_fim    date,
  label          text,
  sprint_id      integer,
  texto          text not null,
  dados          jsonb,
  criado_por     uuid references profiles(id) on delete set null,
  created_at     timestamptz default now()
);
alter table giros add column if not exists dados jsonb;
create index if not exists idx_giros_periodo on giros(periodo_inicio, periodo_fim);
alter table giros enable row level security;
drop policy if exists giros_read  on giros;
drop policy if exists giros_write on giros;
create policy giros_read  on giros for select using (auth.role() = 'authenticated');
create policy giros_write on giros for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- =====================================================
-- ATIVIDADES CUSTOMIZADAS (PA / Auditoria)
-- =====================================================
create table if not exists custom_actions (
  id           uuid primary key default gen_random_uuid(),
  tipo         text not null check (tipo in ('pa','audit')),
  grupo        text,
  titulo       text not null,
  descricao    text,
  resp         text,
  interv       text,
  prazo        date,
  status       text default 'Não iniciado',
  sprint_id    integer,
  vinculo_tipo text check (vinculo_tipo in ('entrega','tarefa') or vinculo_tipo is null),
  entrega_ref  text,
  tarefa_id    uuid references subtarefas(id) on delete set null,
  oculto       boolean default false,
  novo_prazo   date,
  prazo_motivo text,
  obs          text,
  criado_por   uuid references profiles(id) on delete set null,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);
create index if not exists idx_custom_actions_tipo on custom_actions(tipo);
drop trigger if exists t_custom_upd on custom_actions;
create trigger t_custom_upd before update on custom_actions
  for each row execute function set_updated_at();
alter table custom_actions enable row level security;
drop policy if exists custom_actions_read  on custom_actions;
drop policy if exists custom_actions_write on custom_actions;
create policy custom_actions_read  on custom_actions for select using (auth.role() = 'authenticated');
create policy custom_actions_write on custom_actions for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

alter table task_comments    add column if not exists custom_id uuid references custom_actions(id) on delete cascade;
alter table task_attachments add column if not exists custom_id uuid references custom_actions(id) on delete cascade;
create index if not exists idx_task_comments_custom    on task_comments(custom_id);
create index if not exists idx_task_attachments_custom on task_attachments(custom_id);

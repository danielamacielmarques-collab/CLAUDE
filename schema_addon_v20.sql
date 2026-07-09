-- ============================================================
-- NID/COBEN Agile Board v20 — ADDON
-- 1) Giros da Semana salvos (histórico do resumo com IA)
-- 2) Atividades customizadas em Plano de Ação e Auditoria
--    (criar/excluir novas ações, com anexos e comentários)
-- ============================================================
-- Execute APÓS o schema_addon_v19.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

-- ---------- GIROS DA SEMANA SALVOS ----------
create table if not exists giros (
  id             uuid primary key default gen_random_uuid(),
  periodo_inicio date,
  periodo_fim    date,
  label          text,
  sprint_id      integer,
  texto          text not null,
  criado_por     uuid references profiles(id) on delete set null,
  created_at     timestamptz default now()
);
create index if not exists idx_giros_periodo on giros(periodo_inicio, periodo_fim);
alter table giros enable row level security;
drop policy if exists giros_read  on giros;
drop policy if exists giros_write on giros;
create policy giros_read  on giros for select using (auth.role() = 'authenticated');
create policy giros_write on giros for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ---------- ATIVIDADES CUSTOMIZADAS (PA / Auditoria) ----------
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

-- comentários e anexos de atividades customizadas
alter table task_comments    add column if not exists custom_id uuid references custom_actions(id) on delete cascade;
alter table task_attachments add column if not exists custom_id uuid references custom_actions(id) on delete cascade;
create index if not exists idx_task_comments_custom    on task_comments(custom_id);
create index if not exists idx_task_attachments_custom on task_attachments(custom_id);

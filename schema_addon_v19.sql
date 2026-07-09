-- ============================================================
-- NID/COBEN Agile Board v19 — ADDON
-- Gestão avançada de ações (PA e Auditoria):
-- ocultar, cancelar/bloquear (status), repactuar prazo,
-- comentários e anexos por ação.
-- ============================================================
-- Execute APÓS o schema_addon_v18.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

-- pa_items / audit_items: campos de gestão
alter table pa_items    add column if not exists oculto       boolean default false;
alter table pa_items    add column if not exists novo_prazo   date;
alter table pa_items    add column if not exists prazo_motivo text;

alter table audit_items add column if not exists oculto       boolean default false;
alter table audit_items add column if not exists novo_prazo   date;
alter table audit_items add column if not exists prazo_motivo text;

-- Comentários e anexos vinculados a ações do PA / Auditoria
alter table task_comments    add column if not exists pa_idx    integer;
alter table task_comments    add column if not exists audit_idx integer;
alter table task_attachments add column if not exists pa_idx    integer;
alter table task_attachments add column if not exists audit_idx integer;

create index if not exists idx_task_comments_pa       on task_comments(pa_idx);
create index if not exists idx_task_comments_audit    on task_comments(audit_idx);
create index if not exists idx_task_attachments_pa    on task_attachments(pa_idx);
create index if not exists idx_task_attachments_audit on task_attachments(audit_idx);

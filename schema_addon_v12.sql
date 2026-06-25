-- ============================================================
-- NID/COBEN Agile Board v12 — ADDON
-- Anexos e comentários por ocorrência (recorrentes não compartilham)
-- ============================================================
-- Execute APÓS o schema_addon_v11.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

-- Para eventos recorrentes (weekly), cada data tem seus próprios anexos/comentários
alter table task_attachments add column if not exists evento_data date;
alter table task_comments    add column if not exists evento_data date;

create index if not exists idx_task_attachments_evento_data on task_attachments(evento_id, evento_data);
create index if not exists idx_task_comments_evento_data    on task_comments(evento_id, evento_data);

-- ============================================================
-- NID/COBEN Agile Board v9 — ADDON
-- Anexos e comentários em eventos do calendário (loop de temas, ata)
-- ============================================================
-- Execute APÓS o schema_addon_v8.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

-- =====================================================
-- task_attachments e task_comments aceitam evento_id
-- =====================================================
alter table task_attachments
  add column if not exists evento_id uuid references calendar_events(id) on delete cascade;
alter table task_comments
  add column if not exists evento_id uuid references calendar_events(id) on delete cascade;

create index if not exists idx_task_attachments_evento on task_attachments(evento_id);
create index if not exists idx_task_comments_evento    on task_comments(evento_id);

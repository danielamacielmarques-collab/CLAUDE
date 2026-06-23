-- ============================================================
-- NID/COBEN Agile Board v10 — ADDON
-- Comentarios e anexos por OCORRENCIA em eventos recorrentes
-- ============================================================
-- Execute APOS o schema_addon_v9.sql
-- Idempotente: pode ser executada varias vezes
-- ============================================================

-- =====================================================
-- Coluna ocorrencia_data: a data da ocorrencia clicada
-- (para eventos nao recorrentes, e igual a calendar_events.data)
-- =====================================================
alter table task_comments
  add column if not exists ocorrencia_data date;
alter table task_attachments
  add column if not exists ocorrencia_data date;

-- Backfill: comentarios/anexos antigos ficam ancorados na data base do evento
update task_comments c
   set ocorrencia_data = e.data
  from calendar_events e
 where c.evento_id = e.id
   and c.ocorrencia_data is null;

update task_attachments a
   set ocorrencia_data = e.data
  from calendar_events e
 where a.evento_id = e.id
   and a.ocorrencia_data is null;

create index if not exists idx_task_comments_evento_occ
  on task_comments(evento_id, ocorrencia_data);
create index if not exists idx_task_attachments_evento_occ
  on task_attachments(evento_id, ocorrencia_data);

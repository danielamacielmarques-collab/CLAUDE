-- ============================================================
-- NID/COBEN Agile Board v14 — ADDON
-- Novos status: despriorizado, cancelado
-- ============================================================
-- Execute APÓS o schema_addon_v13.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

-- Amplia check constraint de status em sprint_entregas
alter table sprint_entregas drop constraint if exists sprint_entregas_status_check;
alter table sprint_entregas add constraint sprint_entregas_status_check
  check (status in ('pendente','em_andamento','em_revisao','concluido','bloqueado','despriorizado','cancelado'));

-- Amplia check constraint de status em subtarefas
alter table subtarefas drop constraint if exists subtarefas_status_check;
alter table subtarefas add constraint subtarefas_status_check
  check (status in ('pendente','em_andamento','em_revisao','concluido','bloqueado','despriorizado','cancelado'));

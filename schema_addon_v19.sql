-- ============================================================
-- NID/COBEN Agile Board v19 — ADDON
-- Lembretes automáticos — log de envios + configuração via pg_cron
-- ============================================================
-- Execute APÓS o schema_addon_v18.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

-- Log de lembretes enviados (opcional — para auditoria no banco)
create table if not exists reminder_log (
  id           uuid primary key default gen_random_uuid(),
  tipo         text not null,                   -- 'teams', 'email'
  destinatario text,
  conteudo     text,
  status       text default 'enviado',          -- 'enviado', 'erro'
  error_msg    text,
  created_at   timestamptz default now()
);

create index if not exists idx_reminder_log_dt on reminder_log(created_at desc);

alter table reminder_log enable row level security;
drop policy if exists reminder_log_read  on reminder_log;
drop policy if exists reminder_log_write on reminder_log;
create policy reminder_log_read  on reminder_log for select using (auth.role() = 'authenticated');
create policy reminder_log_write on reminder_log for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ============================================================
-- AUTOMAÇÃO VIA pg_cron + pg_net (opcional)
-- ============================================================
-- Para envio 100% automático (sem app aberto), habilite as extensões:
--   1. No Supabase Dashboard: Database → Extensions → Habilite pg_cron e pg_net
--   2. Execute os comandos abaixo:
--
-- Agendar lembrete diário (seg-sex às 08:00 BRT = 11:00 UTC):
-- select cron.schedule(
--   'nid-lembretes-diarios',
--   '0 11 * * 1-5',
--   $$select net.http_post(
--     url := 'https://oclmebkrgazsrujnaywg.supabase.co/functions/v1/send-reminders',
--     headers := '{"Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9jbG1lYmtyZ2F6c3J1am5heXdnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODExOTc5NDgsImV4cCI6MjA5Njc3Mzk0OH0.TcxaOvLl_lnI3dViT3xvSweL7ho3tzDVr1Spuc0TtVE"}'::jsonb,
--     body := '{}'::jsonb
--   );$$
-- );
--
-- Para verificar agendamentos:
-- select * from cron.job;
--
-- Para remover:
-- select cron.unschedule('nid-lembretes-diarios');

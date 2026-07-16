-- ============================================================
-- NID/COBEN Agile Board v21 — ADDON
-- Giro da Semana em formato "jornal": guarda a edição estruturada
-- (JSON) além do texto, para renderizar o layout de jornal.
-- ============================================================
-- Execute APÓS o schema_addon_v20.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

alter table giros add column if not exists dados jsonb;

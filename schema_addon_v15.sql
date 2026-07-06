-- ============================================================
-- NID/COBEN Agile Board v15 — ADDON
-- Perfis de equipe ricos: foto, bio, cargo, habilidades, projetos
-- ============================================================
-- Execute APÓS o schema_addon_v14.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

alter table profiles add column if not exists foto_url           text;
alter table profiles add column if not exists bio                text;
alter table profiles add column if not exists senioridade        text;
alter table profiles add column if not exists habilidades        jsonb default '[]'::jsonb;
alter table profiles add column if not exists projetos_liderados text;

-- As fotos de avatar são armazenadas no bucket 'task-files' (já público),
-- sob o prefixo avatars/. Nenhuma policy adicional é necessária.
-- Caso o bucket ainda não exista, rode o schema_addon.sql.

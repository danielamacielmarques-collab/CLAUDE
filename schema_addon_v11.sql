-- ============================================================
-- NID/COBEN Agile Board v11 — ADDON
-- Responsaveis de acompanhamento por item do Plano COPEP
-- ============================================================
-- Execute APOS schema_addon_v10.sql
-- Idempotente
-- ============================================================

create table if not exists copep_acompanhantes (
  id          uuid primary key default gen_random_uuid(),
  copep_key   text not null,
  profile_id  uuid not null references profiles(id) on delete cascade,
  papel       text default 'acompanhante'
                check (papel in ('acompanhante','responsavel','observador')),
  created_at  timestamptz default now(),
  unique(copep_key, profile_id)
);

create index if not exists idx_copep_acmp_key
  on copep_acompanhantes(copep_key);
create index if not exists idx_copep_acmp_profile
  on copep_acompanhantes(profile_id);

alter table copep_acompanhantes enable row level security;
drop policy if exists copep_acmp_read   on copep_acompanhantes;
drop policy if exists copep_acmp_write  on copep_acompanhantes;
drop policy if exists copep_acmp_delete on copep_acompanhantes;

create policy copep_acmp_read   on copep_acompanhantes
  for select using (auth.role() = 'authenticated');
create policy copep_acmp_write  on copep_acompanhantes
  for insert to authenticated with check (auth.role() = 'authenticated');
create policy copep_acmp_delete on copep_acompanhantes
  for delete to authenticated using (auth.role() = 'authenticated');

-- ============================================================
-- NID/COBEN Agile Board v18 — ADDON
-- OM Status (descontinuação de Oportunidades de Melhoria)
-- ============================================================
-- Execute APÓS o schema_addon_v17.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

create table if not exists pa_om_status (
  id              uuid primary key default gen_random_uuid(),
  om_id           integer not null unique,
  descontinuado   boolean default false,
  justificativa   text,
  descontinuado_por uuid references profiles(id) on delete set null,
  descontinuado_em timestamptz,
  updated_at      timestamptz default now()
);

create index if not exists idx_pa_om_status_om on pa_om_status(om_id);

drop trigger if exists t_pa_om_upd on pa_om_status;
create trigger t_pa_om_upd before update on pa_om_status
  for each row execute function set_updated_at();

alter table pa_om_status enable row level security;
drop policy if exists pa_om_status_read  on pa_om_status;
drop policy if exists pa_om_status_write on pa_om_status;
create policy pa_om_status_read  on pa_om_status for select using (auth.role() = 'authenticated');
create policy pa_om_status_write on pa_om_status for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ============================================================
-- NID/COBEN Agile Board v7 — ADDON
-- Tipo de usuário (papel) + Admin + Audit Log de Governança
-- ============================================================
-- Execute APÓS o schema_addon.sql v6.
-- Idempotente: pode ser executada várias vezes.
-- ============================================================

-- =====================================================
-- PROFILES — coluna "tipo" (papel do usuário)
-- =====================================================
alter table profiles add column if not exists tipo text default 'integrante';

-- Backfill: usuários existentes
update profiles set tipo='integrante'
  where tipo is null or tipo='';

-- Promove a administradora padrão (idempotente)
update profiles set tipo='admin'
  where lower(email) = 'daniela.ribas@funcef.com.br';

-- Constraint (idempotente)
do $$ begin
  alter table profiles add constraint profiles_tipo_check
    check (tipo in ('admin','integrante','gestor','coordenador','visitante'));
exception when duplicate_object then null; when others then null; end $$;

-- =====================================================
-- Trigger handle_new_user — lê tipo da metadata + auto-admin
-- =====================================================
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  nome_full text;
  iniciais_calc text;
  cores text[] := array['#2B6AFF','#FF7B39','#22D172','#A78BFA','#EC4899','#F5A524','#14B8A6','#FF4757'];
  cor_pick text;
  tipo_pick text;
begin
  nome_full := coalesce(new.raw_user_meta_data->>'nome', split_part(new.email, '@', 1));
  iniciais_calc := upper(
    substring(split_part(nome_full,' ',1) from 1 for 1) ||
    coalesce(substring(split_part(nome_full,' ',2) from 1 for 1), '')
  );
  cor_pick := cores[1 + (abs(hashtext(new.id::text)) % array_length(cores,1))];
  tipo_pick := coalesce(new.raw_user_meta_data->>'tipo','integrante');
  -- Auto-admin para o e-mail da administradora padrão
  if lower(new.email) = 'daniela.ribas@funcef.com.br' then
    tipo_pick := 'admin';
  end if;
  insert into profiles (id, email, nome, iniciais, cor, area, tipo)
    values (new.id, new.email, nome_full, iniciais_calc, cor_pick,
            coalesce(new.raw_user_meta_data->>'area','NID'),
            tipo_pick);
  return new;
end;$$;

-- =====================================================
-- AUDIT LOG — Governança
-- =====================================================
create table if not exists audit_log (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid references profiles(id) on delete set null,
  action      text not null,
  entity_type text not null,
  entity_id   text,
  sprint_id   integer,
  summary     text,
  details     jsonb,
  created_at  timestamptz default now()
);
create index if not exists idx_audit_sprint  on audit_log(sprint_id, created_at desc);
create index if not exists idx_audit_profile on audit_log(profile_id, created_at desc);
create index if not exists idx_audit_action  on audit_log(action, created_at desc);

alter table audit_log enable row level security;
drop policy if exists audit_log_read   on audit_log;
drop policy if exists audit_log_insert on audit_log;

create policy audit_log_read   on audit_log for select using (auth.role() = 'authenticated');
create policy audit_log_insert on audit_log for insert to authenticated with check (auth.role() = 'authenticated');
-- Auditoria nao deve ser editavel; apenas insercao e leitura

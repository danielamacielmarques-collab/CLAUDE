-- ============================================================
-- NID/COBEN — Agile Board v4 | Schema Supabase com Auth
-- Execute no SQL Editor do projeto Supabase
-- ============================================================
-- Pré-requisito: Supabase Auth deve estar habilitado (já vem por padrão)
-- ============================================================

drop table if exists checklist_items cascade;
drop table if exists task_members  cascade;
drop table if exists task_tags     cascade;
drop table if exists entrega_members cascade;
drop table if exists sprint_entregas cascade;
drop table if exists sprint_reviews  cascade;
drop table if exists subtarefas      cascade;
drop table if exists tags            cascade;
drop table if exists profiles        cascade;

-- =====================================================
-- PROFILES (vinculados ao auth.users do Supabase)
-- =====================================================
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text unique,
  nome        text not null,
  iniciais    text not null,
  cor         text not null default '#2B6AFF',
  area        text default 'NID',
  cargo       text,
  ativo       boolean default true,
  created_at  timestamptz default now()
);

-- Trigger: ao criar user no auth, cria profile automático
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  nome_full text;
  iniciais_calc text;
  cores text[] := array['#2B6AFF','#FF7B39','#22D172','#A78BFA','#EC4899','#F5A524','#14B8A6','#FF4757'];
  cor_pick text;
begin
  nome_full := coalesce(new.raw_user_meta_data->>'nome', split_part(new.email, '@', 1));
  iniciais_calc := upper(
    substring(split_part(nome_full,' ',1) from 1 for 1) ||
    coalesce(substring(split_part(nome_full,' ',2) from 1 for 1), '')
  );
  cor_pick := cores[1 + (abs(hashtext(new.id::text)) % array_length(cores,1))];
  insert into profiles (id, email, nome, iniciais, cor, area)
    values (new.id, new.email, nome_full, iniciais_calc, cor_pick,
            coalesce(new.raw_user_meta_data->>'area','NID'));
  return new;
end;$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- =====================================================
-- TAGS (área + customizadas)
-- =====================================================
create table tags (
  id    uuid primary key default gen_random_uuid(),
  nome  text not null,
  cor   text not null,
  tipo  text default 'area'  check (tipo in ('area','custom'))
);
insert into tags (nome,cor,tipo) values
  ('Dados',      '#2B6AFF','area'),
  ('Inovação',   '#A78BFA','area'),
  ('SUITE',      '#EC4899','area'),
  ('Automação',  '#FF7B39','area'),
  ('Painéis',    '#22D172','area'),
  ('Governança', '#6366F1','area'),
  ('NEXUS',      '#14B8A6','area'),
  ('Urgente',    '#FF4757','custom'),
  ('Revisão',    '#F5A524','custom');

-- =====================================================
-- SPRINT ENTREGAS planejadas (do calendário 2026-2027)
-- =====================================================
create table sprint_entregas (
  id            uuid primary key default gen_random_uuid(),
  sprint_id     integer not null,
  entrega_idx   integer not null,
  status        text not null default 'pendente'
                  check (status in ('pendente','em_andamento','em_revisao','concluido','bloqueado')),
  obs           text,
  data_inicio   date,
  data_fim      date,
  updated_at    timestamptz default now(),
  unique (sprint_id, entrega_idx)
);

create table entrega_members (
  id          uuid primary key default gen_random_uuid(),
  sprint_id   integer not null,
  entrega_idx integer not null,
  profile_id  uuid references profiles(id) on delete cascade,
  unique(sprint_id, entrega_idx, profile_id)
);

-- =====================================================
-- SUBTAREFAS (tarefas livres com fase do ciclo)
-- =====================================================
create table subtarefas (
  id            uuid primary key default gen_random_uuid(),
  sprint_id     integer not null,
  entrega_idx   integer,
  titulo        text not null,
  descricao     text,
  status        text not null default 'pendente'
                  check (status in ('pendente','em_andamento','em_revisao','concluido','bloqueado')),
  prioridade    text not null default 'media'
                  check (prioridade in ('critica','alta','media','baixa')),
  fase          text not null default 'ideacao'
                  check (fase in ('ideacao','business_case','planejamento','execucao','homologacao','implantacao','encerramento')),
  story_points  integer,
  data_inicio   date,
  data_fim      date,
  progresso     integer default 0 check (progresso between 0 and 100),
  criado_por    uuid references profiles(id) on delete set null,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

create table task_members (
  id         uuid primary key default gen_random_uuid(),
  tarefa_id  uuid references subtarefas(id) on delete cascade,
  profile_id uuid references profiles(id)   on delete cascade,
  papel      text default 'executor' check (papel in ('executor','revisor','observador')),
  unique(tarefa_id, profile_id)
);

create table task_tags (
  id        uuid primary key default gen_random_uuid(),
  tarefa_id uuid references subtarefas(id) on delete cascade,
  tag_id    uuid references tags(id)       on delete cascade,
  unique(tarefa_id, tag_id)
);

create table checklist_items (
  id         uuid primary key default gen_random_uuid(),
  tarefa_id  uuid references subtarefas(id) on delete cascade,
  texto      text not null,
  concluido  boolean default false,
  ordem      integer default 0,
  created_at timestamptz default now()
);

-- =====================================================
-- SPRINT REVIEWS
-- =====================================================
create table sprint_reviews (
  id                  uuid primary key default gen_random_uuid(),
  sprint_id           integer not null unique,
  entregas_realizadas text,
  riscos_bloqueadores text,
  proximas_acoes      text,
  percentual_entregue integer,
  velocidade_pontos   integer,
  nps_equipe          integer,
  data_realizacao     date,
  updated_at          timestamptz default now()
);

-- =====================================================
-- TRIGGERS updated_at
-- =====================================================
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;$$;

create trigger t_se_upd  before update on sprint_entregas for each row execute function set_updated_at();
create trigger t_st_upd  before update on subtarefas      for each row execute function set_updated_at();
create trigger t_sr_upd  before update on sprint_reviews  for each row execute function set_updated_at();

-- =====================================================
-- RLS — usuários autenticados leem tudo, podem escrever
-- =====================================================
do $$ declare t text;
begin
  foreach t in array array[
    'profiles','tags','sprint_entregas','entrega_members',
    'subtarefas','task_members','task_tags','checklist_items','sprint_reviews'
  ] loop
    execute format('alter table %I enable row level security', t);
    execute format($f$create policy %I on %I for select using (auth.role() = 'authenticated')$f$, t || '_read',  t);
    execute format($f$create policy %I on %I for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated')$f$, t || '_write', t);
  end loop;
end$$;

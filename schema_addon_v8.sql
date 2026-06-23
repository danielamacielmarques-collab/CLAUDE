-- ============================================================
-- NID/COBEN Agile Board v8 — ADDON
-- Calendário: eventos, reuniões, atividades, weekly, vinculação a pessoas
-- ============================================================
-- Execute APÓS o schema_addon_v7.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

-- =====================================================
-- CALENDAR EVENTS
-- =====================================================
create table if not exists calendar_events (
  id           uuid primary key default gen_random_uuid(),
  tipo         text default 'reuniao'
                 check (tipo in ('reuniao','tarefa','atividade','weekly','outro')),
  titulo       text not null,
  descricao    text,
  data         date not null,
  hora_inicio  time,
  hora_fim     time,
  local        text,
  duracao_min  integer,
  recorrente   boolean default false,
  recorrencia  text check (recorrencia in ('semanal','quinzenal','mensal','nenhuma') or recorrencia is null),
  cor          text default '#2B6AFF',
  sprint_id    integer,
  criado_por   uuid references profiles(id) on delete set null,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

create index if not exists idx_calendar_events_data on calendar_events(data);
create index if not exists idx_calendar_events_tipo on calendar_events(tipo);

-- Trigger updated_at (idempotente)
drop trigger if exists t_ce_upd on calendar_events;
create trigger t_ce_upd before update on calendar_events
  for each row execute function set_updated_at();

-- =====================================================
-- EVENT MEMBERS — quem participa
-- =====================================================
create table if not exists event_members (
  id         uuid primary key default gen_random_uuid(),
  evento_id  uuid references calendar_events(id) on delete cascade,
  profile_id uuid references profiles(id) on delete cascade,
  unique(evento_id, profile_id)
);
create index if not exists idx_event_members_evento on event_members(evento_id);

-- =====================================================
-- RLS
-- =====================================================
alter table calendar_events enable row level security;
alter table event_members   enable row level security;

drop policy if exists calendar_events_read  on calendar_events;
drop policy if exists calendar_events_write on calendar_events;
drop policy if exists event_members_read    on event_members;
drop policy if exists event_members_write   on event_members;

create policy calendar_events_read  on calendar_events for select using (auth.role() = 'authenticated');
create policy calendar_events_write on calendar_events for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy event_members_read    on event_members   for select using (auth.role() = 'authenticated');
create policy event_members_write   on event_members   for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- =====================================================
-- Weekly NID — semente padrão (só insere se não houver nenhum 'weekly')
-- =====================================================
do $$ begin
  if not exists (select 1 from calendar_events where tipo='weekly') then
    insert into calendar_events (tipo, titulo, descricao, data, hora_inicio, hora_fim, local, duracao_min, recorrente, recorrencia, cor)
    values ('weekly', 'Weekly do Núcleo de Dados', 'Reunião semanal de alinhamento do NID — bloqueios, andamento e próximos passos', '2026-06-04', '15:00', '16:00', 'Teams (link da equipe)', 60, true, 'semanal', '#FF7B39');
  end if;
end $$;

-- ============================================================
-- NID/COBEN Agile Board v20 — ADDON
-- Riscos Organizacionais — gestão de riscos e controles COBEN
-- ============================================================
-- Execute APÓS o schema_addon_v19.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

-- 1. Tabela de riscos
create table if not exists riscos (
  id             uuid primary key default gen_random_uuid(),
  codigo         text not null,
  titulo         text not null,
  abordagem      text not null default 'Operacional'
                   check (abordagem in ('Operacional','Organizacionais')),
  ciclo          text default '2026',
  status         text default 'manutencao'
                   check (status in ('manutencao','mitigacao','aceito','transferido','eliminado')),
  controles      jsonb default '[]'::jsonb,
  nivel_residual text check (nivel_residual in ('baixo','moderado','alto','extremo') or nivel_residual is null),
  plano_acao     text,
  observacoes    text,
  vinculo_tipo   text check (vinculo_tipo in ('entrega','tarefa') or vinculo_tipo is null),
  vinculo_ref    text,
  tarefa_id      uuid references subtarefas(id) on delete set null,
  sprint_id      integer,
  created_by     uuid references profiles(id) on delete set null,
  updated_at     timestamptz default now(),
  created_at     timestamptz default now()
);

-- Constraint UNIQUE em codigo (necessária para ON CONFLICT)
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'riscos_codigo_key' and conrelid = 'riscos'::regclass
  ) then
    alter table riscos add constraint riscos_codigo_key unique (codigo);
  end if;
end $$;

-- 2. Trigger updated_at
do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'set_riscos_updated_at'
  ) then
    create trigger set_riscos_updated_at
      before update on riscos
      for each row execute function set_updated_at();
  end if;
end $$;

-- 3. RLS
alter table riscos enable row level security;

drop policy if exists "Authenticated users can read riscos" on riscos;
create policy "Authenticated users can read riscos"
  on riscos for select
  to authenticated
  using (true);

drop policy if exists "Authenticated users can insert riscos" on riscos;
create policy "Authenticated users can insert riscos"
  on riscos for insert
  to authenticated
  with check (true);

drop policy if exists "Authenticated users can update riscos" on riscos;
create policy "Authenticated users can update riscos"
  on riscos for update
  to authenticated
  using (true)
  with check (true);

drop policy if exists "Authenticated users can delete riscos" on riscos;
create policy "Authenticated users can delete riscos"
  on riscos for delete
  to authenticated
  using (true);

-- 4. Índice em abordagem + ciclo
create index if not exists idx_riscos_abordagem_ciclo
  on riscos (abordagem, ciclo);

-- 5. Seed — 6 riscos iniciais
insert into riscos (codigo, titulo, abordagem, ciclo, status, controles)
values
  (
    '678',
    'Cálculo do benefício inconsistente',
    'Operacional',
    '2026',
    'manutencao',
    '[
      {"codigo":"C 2025","descricao":"Relatório de críticas, gerado no fechamento das concessões"},
      {"codigo":"C 2025","descricao":"Dupla checagem (Normatizado no MEG 048 - Manutenção de Benefícios FUNCEF)"},
      {"codigo":"C 2025","descricao":"Conferência das informações apresentadas pelas áreas e batimento dos cálculos em planilhas de Excel"},
      {"codigo":"C 2018","descricao":"Conferência da Concessão de Benefícios"}
    ]'::jsonb
  ),
  (
    '1427',
    'Manutenção dos benefícios com inconsistência (legado)',
    'Operacional',
    '2026',
    'manutencao',
    '[
      {"codigo":"C 2023","descricao":"Mensagens eletrônicas para retenção de benefícios enviadas diariamente pela COCAD para encerramento de benefícios"},
      {"codigo":"C 2023","descricao":"Relatórios de conciliação BI e Planus"},
      {"codigo":"C 2023","descricao":"Mensagens eletrônicas direcionadas à COBEN referente à retenção e reativação dos benefícios (processo prova de vida)"},
      {"codigo":"C 2023","descricao":"Dupla checagem - Normatizado no MEG 048 - Manutenção de Benefícios FUNCEF"},
      {"codigo":"C 2023","descricao":"Funcionalidade de controle das dívidas previdenciárias no Sistema Planus"},
      {"codigo":"C 2018","descricao":"Controle das Revisões efetuadas - Planilha Excel"},
      {"codigo":"C 2023","descricao":"Conferência das informações apresentadas pelas áreas e batimento do cálculo"},
      {"codigo":"C 2025","descricao":"Tratamento do Legado"}
    ]'::jsonb
  ),
  (
    '1428',
    'Execução de atividades manuais',
    'Operacional',
    '2026',
    'manutencao',
    '[
      {"codigo":"C 2023","descricao":"Conferência das informações apresentadas pelas áreas e batimento do cálculo em planilha de Excel"},
      {"codigo":"C 2025","descricao":"Relatório de críticas, gerado no fechamento das concessões"},
      {"codigo":"C 2023","descricao":"Dupla checagem - Normatizado no MEG 048 - Manutenção de Benefícios FUNCEF"},
      {"codigo":"C 2025","descricao":"Escritório de projetos, designação de um PMO e grupo no TEAMS, para atendimento tempestivo das demandas de erro"}
    ]'::jsonb
  ),
  (
    '2258',
    'Execução do Contrato INSS - Pagamento de benefícios com inconsistência',
    'Operacional',
    '2026',
    'manutencao',
    '[
      {"codigo":"C 2026","descricao":"Reuniões periódicas com a Diretoria de Benefícios do INSS para agilizar a regularização dos valores"},
      {"codigo":"C 2026","descricao":"Revisão do benefício processada em funcionalidade do Sistema PLANUS"},
      {"codigo":"C 2026","descricao":"Funcionalidade com o extrato individual com registros financeiros do benefício do INSS"},
      {"codigo":"C 2018","descricao":"Controle das Revisões efetuadas - Planilha Excel"}
    ]'::jsonb
  ),
  (
    'RS1482',
    'Inobservância, violação ou interpretação indevida de regulamentações e normativos internos/externos',
    'Organizacionais',
    '2026',
    'manutencao',
    '[
      {"codigo":"C 2026","descricao":"Acompanhamento de Legislações - SIMCO (Monitoramento contínuo de alterações legislativas, normativas e regulatórias por meio do SIMCO)"},
      {"codigo":"C 2026","descricao":"Dupla checagem (Realização de conferência e validação por segundo empregado nos processos de análise, cálculo e concessão de benefícios)"},
      {"codigo":"C 2026","descricao":"Treinamentos contínuos para os empregados"}
    ]'::jsonb
  ),
  (
    'RS1483',
    'Ações ajuizadas ou ações contra',
    'Organizacionais',
    '2026',
    'manutencao',
    '[
      {"codigo":"C 2026","descricao":"Divulgação transparente das regras dos planos para os participantes"},
      {"codigo":"C 2026","descricao":"Treinamentos contínuos para os empregados"},
      {"codigo":"C 2026","descricao":"Dupla checagem (Realização de conferência e validação por segundo empregado nos processos de análise, cálculo e concessão de benefícios)"}
    ]'::jsonb
  )
on conflict (codigo) do nothing;

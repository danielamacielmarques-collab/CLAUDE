# Plano de Migração Supabase → Dataverse

## Índice

1. [Visão Geral](#visão-geral)
2. [Mapeamento de Tipos](#mapeamento-de-tipos)
3. [Ordem de Migração](#ordem-de-migração)
4. [Tabela 1: profiles](#tabela-1-profiles)
5. [Tabela 2: tags](#tabela-2-tags)
6. [Tabela 3: sprint_entregas](#tabela-3-sprint_entregas)
7. [Tabela 4: entrega_members](#tabela-4-entrega_members)
8. [Tabela 5: subtarefas](#tabela-5-subtarefas)
9. [Tabela 6: task_members](#tabela-6-task_members)
10. [Tabela 7: task_tags](#tabela-7-task_tags)
11. [Tabela 8: checklist_items](#tabela-8-checklist_items)
12. [Tabela 9: task_comments](#tabela-9-task_comments)
13. [Tabela 10: task_attachments](#tabela-10-task_attachments)
14. [Tabela 11: sprint_reviews](#tabela-11-sprint_reviews)
15. [Tabela 12: sprint_review_items](#tabela-12-sprint_review_items)
16. [Tabela 13: calendar_events](#tabela-13-calendar_events)
17. [Tabela 14: event_members](#tabela-14-event_members)
18. [Tabela 15: audit_log](#tabela-15-audit_log)
19. [Tabela 16: pa_items](#tabela-16-pa_items)
20. [Tabela 17: pa_om_status](#tabela-17-pa_om_status)
21. [Tabela 18: ideias](#tabela-18-ideias)
22. [Tabela 19: riscos](#tabela-19-riscos)
23. [Tabela 20: reminder_log](#tabela-20-reminder_log)
24. [Relacionamentos N:N](#relacionamentos-nn)
25. [Scripts de Exportação Supabase](#scripts-de-exportação-supabase)
26. [Procedimento de Importação](#procedimento-de-importação)
27. [Validação Pós-Migração](#validação-pós-migração)

---

## Visão Geral

### Resumo Quantitativo

| Métrica | Quantidade |
|---------|-----------|
| Tabelas a migrar | 20 |
| Colunas totais | ~140 |
| Relacionamentos (Lookup) | 22 |
| Relacionamentos N:N | 1 (task_tags) |
| Choice columns | 18 |
| Funções/Triggers | Substituídos por Power Automate |
| RLS Policies | Substituídas por Security Roles |

### O que NÃO migra

| Supabase | Motivo | Substituição no Dataverse |
|----------|--------|--------------------------|
| `auth.users` | Gerenciado pelo Entra ID | Tabela `systemuser` (nativa) |
| Triggers `set_updated_at()` | Dataverse tem `Modified On` automático | Automático |
| Trigger `handle_new_user()` | Entra ID gerencia criação de usuário | Power Automate |
| RLS Policies | Modelo de segurança diferente | Security Roles + Business Units |
| Storage bucket `task-files` | Supabase Storage | SharePoint / Dataverse File columns |
| Função `delete_user_admin()` | RPC Supabase | Power Automate + Entra ID Admin |

---

## Mapeamento de Tipos

| Tipo Supabase (PostgreSQL) | Tipo Dataverse | Notas |
|---------------------------|----------------|-------|
| `uuid` (PK) | `Uniqueidentifier` (GUID) | Gerado automaticamente |
| `text` | `Single Line of Text` (max 4000) | Use `Multiple Lines of Text` se > 256 chars |
| `text` (multilinha) | `Multiple Lines of Text` | Formato: Rich Text ou Plain |
| `integer` | `Whole Number` | Range: -2.147.483.648 a 2.147.483.647 |
| `bigint` | `Whole Number` (Big Integer) | Para tamanhos de arquivo |
| `boolean` | `Two Options` (Yes/No) | |
| `date` | `Date Only` | Formato: Date Only |
| `time` | `Single Line of Text` | Dataverse não tem tipo Time puro |
| `timestamptz` | `Date and Time` | Comportamento: User Local |
| `decimal` | `Decimal Number` | Precisão configurável |
| `jsonb` | `Multiple Lines of Text` (JSON) | Ou tabela filho (recomendado) |
| `text` com `CHECK IN(...)` | `Choice` (Option Set) | Valores enumerados |
| `uuid REFERENCES ...` | `Lookup` | Relacionamento N:1 |
| `integer` (sprint_id) | `Whole Number` | Sprint não é tabela no Supabase, é inteiro |

### Sobre `sprint_id` (integer)

No schema Supabase, **sprints não têm tabela própria** — o `sprint_id` é um inteiro (1, 2, 3...) e os dados da sprint (nome, datas, entregas) são definidos no catálogo JavaScript do `index.html`.

**Decisão para Dataverse**: Criar uma tabela `nid_Sprint` e popular com os dados do catálogo JS. Todos os `sprint_id` integer viram **Lookup** para essa tabela.

---

## Ordem de Migração

A ordem respeita as dependências de foreign keys. Siga exatamente esta sequência:

```
FASE 1 — Tabelas independentes (sem FK para outras tabelas NID)
  1. profiles         (vincula ao systemuser do Entra ID)
  2. tags             (sem FK)
  3. nid_Sprint *     (NOVA — criar a partir do catálogo JS)

FASE 2 — Tabelas com FK para Fase 1
  4. sprint_entregas       (FK → sprint_id como Lookup)
  5. calendar_events       (FK → profiles.criado_por)
  6. ideias                (FK → profiles.autor_id)
  7. riscos                (FK → profiles.created_by, subtarefas.id)
  8. pa_items              (FK → subtarefas.id — migrar após subtarefas)

FASE 3 — Tabelas com FK para Fase 2
  9. subtarefas            (FK → profiles, sprint)
  10. sprint_reviews       (FK → profiles, sprint)
  11. pa_om_status         (FK → profiles)

FASE 4 — Tabelas associativas (FK para Fase 2/3)
  12. entrega_members      (FK → profiles)
  13. task_members         (FK → subtarefas, profiles)
  14. task_tags            (FK → subtarefas, tags)
  15. checklist_items      (FK → subtarefas)
  16. task_comments        (FK → subtarefas, profiles, calendar_events)
  17. task_attachments     (FK → subtarefas, profiles, calendar_events, ideias)
  18. event_members        (FK → calendar_events, profiles)
  19. sprint_review_items  (FK → sprint_reviews)

FASE 5 — Tabelas de log (sem FK críticas)
  20. audit_log            (FK → profiles)
  21. reminder_log         (sem FK)
```

---

## Tabela 1: profiles

### Supabase (Schema Atual)

```sql
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text unique,
  nome        text not null,
  iniciais    text not null,
  cor         text not null default '#2B6AFF',
  area        text default 'NID',
  cargo       text,
  ativo       boolean default true,
  created_at  timestamptz default now(),
  -- v7: tipo de usuário
  tipo        text default 'integrante'
              check (tipo in ('admin','integrante','gestor','coordenador','visitante')),
  -- v15: perfil rico
  foto_url           text,
  bio                text,
  senioridade        text,
  habilidades        jsonb default '[]'::jsonb,
  projetos_liderados text
);
```

### Dataverse — Tabela: `nid_Profile`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Default | Notas |
|---|-------------|-------------|----------------|-------------|---------|-------|
| 1 | Nome | `nid_nome` | Single Line of Text (200) | Sim | — | Primary Name column |
| 2 | Email | `nid_email` | Single Line of Text (320) | Sim | — | Unique (Business Rule) |
| 3 | Iniciais | `nid_iniciais` | Single Line of Text (10) | Sim | — | |
| 4 | Cor | `nid_cor` | Single Line of Text (20) | Sim | `#2B6AFF` | Hex color |
| 5 | Área | `nid_area` | Single Line of Text (100) | Não | `NID` | |
| 6 | Cargo | `nid_cargo` | Single Line of Text (200) | Não | — | |
| 7 | Ativo | `nid_ativo` | Two Options (Yes/No) | Sim | Yes | |
| 8 | Tipo | `nid_tipo` | Choice | Sim | Integrante | Ver Choice abaixo |
| 9 | Foto URL | `nid_fotourl` | Single Line of Text (2000) | Não | — | URL ou Image column |
| 10 | Bio | `nid_bio` | Multiple Lines of Text | Não | — | Rich Text |
| 11 | Senioridade | `nid_senioridade` | Single Line of Text (100) | Não | — | |
| 12 | Habilidades | `nid_habilidades` | Multiple Lines of Text | Não | `[]` | JSON string |
| 13 | Projetos Liderados | `nid_projetosliderados` | Multiple Lines of Text | Não | — | |
| 14 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | — | Para rastreio da migração |
| 15 | Usuário AD | `nid_systemuser` | Lookup → systemuser | Não | — | Vincular ao Entra ID |

**Choice: nid_tipo**

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Admin | 100000000 |
| 2 | Integrante | 100000001 |
| 3 | Gestor | 100000002 |
| 4 | Coordenador | 100000003 |
| 5 | Visitante | 100000004 |

**Passo-a-passo no portal:**
1. make.powerapps.com → Tabelas → + Nova tabela
2. Nome da tabela: `Profile`
3. Prefixo do publicador: `nid`
4. Primary Name column: `Nome` (nid_nome)
5. Salvar → Adicionar cada coluna conforme tabela acima
6. Para a coluna `Tipo`: + Nova coluna → Choice → Nova Choice Global → Adicionar as 5 opções

### Exportação Supabase

```sql
-- Exportar profiles do Supabase para CSV
COPY (
  SELECT
    id AS supabase_id,
    email,
    nome,
    iniciais,
    cor,
    area,
    cargo,
    ativo,
    tipo,
    foto_url,
    bio,
    senioridade,
    habilidades::text AS habilidades,
    projetos_liderados,
    created_at
  FROM profiles
  ORDER BY created_at
) TO STDOUT WITH CSV HEADER;
```

Ou no Supabase Dashboard: **Table Editor → profiles → Export → CSV**

---

## Tabela 2: tags

### Supabase

```sql
create table tags (
  id    uuid primary key default gen_random_uuid(),
  nome  text not null,
  cor   text not null,
  tipo  text default 'area' check (tipo in ('area','custom'))
);
```

### Dataverse — Tabela: `nid_Tag`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Default |
|---|-------------|-------------|----------------|-------------|---------|
| 1 | Nome | `nid_nome` | Single Line of Text (100) | Sim | — |
| 2 | Cor | `nid_cor` | Single Line of Text (20) | Sim | — |
| 3 | Tipo | `nid_tipo` | Choice | Sim | Área |
| 4 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | — |

**Choice: nid_tagtipo**

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Área | 100000000 |
| 2 | Custom | 100000001 |

### Dados Iniciais (seed)

| Nome | Cor | Tipo |
|------|-----|------|
| Dados | #2B6AFF | area |
| Inovação | #A78BFA | area |
| SUITE | #EC4899 | area |
| Automação | #FF7B39 | area |
| Painéis | #22D172 | area |
| Governança | #6366F1 | area |
| NEXUS | #14B8A6 | area |
| Urgente | #FF4757 | custom |
| Revisão | #F5A524 | custom |

### Exportação Supabase

```sql
COPY (SELECT id AS supabase_id, nome, cor, tipo FROM tags ORDER BY tipo, nome)
TO STDOUT WITH CSV HEADER;
```

---

## Tabela 3: sprint_entregas

### Supabase

```sql
create table sprint_entregas (
  id            uuid primary key default gen_random_uuid(),
  sprint_id     integer not null,
  entrega_idx   integer not null,
  status        text not null default 'pendente'
                check (status in ('pendente','em_andamento','em_revisao','concluido','bloqueado','despriorizado','cancelado')),
  obs           text,
  data_inicio   date,
  data_fim      date,
  updated_at    timestamptz default now(),
  -- v6: campos extras
  descricao     text,
  prioridade    text default 'media',
  fase          text default 'execucao',
  story_points  integer,
  progresso     integer default 0,
  unique (sprint_id, entrega_idx)
);
```

### Dataverse — Tabela: `nid_Entrega`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Default | Notas |
|---|-------------|-------------|----------------|-------------|---------|-------|
| 1 | Nome | `nid_nome` | Single Line of Text (200) | Sim | — | Primary. Gerar: "Sprint {N} — Entrega {idx}" |
| 2 | Sprint | `nid_sprint` | Lookup → nid_Sprint | Sim | — | Substitui sprint_id integer |
| 3 | Entrega Idx | `nid_entregaidx` | Whole Number | Sim | — | Índice no catálogo |
| 4 | Status | `nid_status` | Choice | Sim | Pendente | Ver Choice abaixo |
| 5 | Observação | `nid_obs` | Multiple Lines of Text | Não | — | |
| 6 | Data Início | `nid_datainicio` | Date Only | Não | — | |
| 7 | Data Fim | `nid_datafim` | Date Only | Não | — | |
| 8 | Descrição | `nid_descricao` | Multiple Lines of Text | Não | — | |
| 9 | Prioridade | `nid_prioridade` | Choice | Não | Média | |
| 10 | Fase | `nid_fase` | Choice | Não | Execução | |
| 11 | Story Points | `nid_storypoints` | Whole Number | Não | — | |
| 12 | Progresso | `nid_progresso` | Whole Number | Não | 0 | Min: 0, Max: 100 |
| 13 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | — | |

**Choice: nid_entregastatus** (reutilizar em subtarefas também)

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Pendente | 100000000 |
| 2 | Em Andamento | 100000001 |
| 3 | Em Revisão | 100000002 |
| 4 | Concluído | 100000003 |
| 5 | Bloqueado | 100000004 |
| 6 | Despriorizado | 100000005 |
| 7 | Cancelado | 100000006 |

**Choice: nid_prioridade** (Global — reutilizar)

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Crítica | 100000000 |
| 2 | Alta | 100000001 |
| 3 | Média | 100000002 |
| 4 | Baixa | 100000003 |

**Choice: nid_fase** (Global — reutilizar)

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Ideação | 100000000 |
| 2 | Business Case | 100000001 |
| 3 | Planejamento | 100000002 |
| 4 | Execução | 100000003 |
| 5 | Homologação | 100000004 |
| 6 | Implantação | 100000005 |
| 7 | Encerramento | 100000006 |

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id, sprint_id, entrega_idx, status,
         obs, data_inicio, data_fim, descricao, prioridade,
         fase, story_points, progresso, updated_at
  FROM sprint_entregas
  ORDER BY sprint_id, entrega_idx
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 4: entrega_members

### Supabase

```sql
create table entrega_members (
  id          uuid primary key default gen_random_uuid(),
  sprint_id   integer not null,
  entrega_idx integer not null,
  profile_id  uuid references profiles(id) on delete cascade,
  unique(sprint_id, entrega_idx, profile_id)
);
```

### Dataverse — Tabela: `nid_EntregaMember`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Notas |
|---|-------------|-------------|----------------|-------------|-------|
| 1 | Nome | `nid_nome` | Single Line of Text | Sim | Auto: "{Profile.Nome} — {Entrega.Nome}" |
| 2 | Entrega | `nid_entrega` | Lookup → nid_Entrega | Sim | Substitui sprint_id + entrega_idx |
| 3 | Profile | `nid_profile` | Lookup → nid_Profile | Sim | |
| 4 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | |

**Nota**: No Supabase a entrega é identificada por `(sprint_id, entrega_idx)`. No Dataverse, a entrega tem seu próprio GUID. Na migração, faça o JOIN para encontrar o GUID correto da entrega.

### Exportação Supabase

```sql
COPY (
  SELECT em.id AS supabase_id, em.sprint_id, em.entrega_idx,
         em.profile_id AS profile_supabase_id
  FROM entrega_members em
  ORDER BY em.sprint_id, em.entrega_idx
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 5: subtarefas

### Supabase

```sql
create table subtarefas (
  id            uuid primary key default gen_random_uuid(),
  sprint_id     integer not null,
  entrega_idx   integer,
  titulo        text not null,
  descricao     text,
  status        text not null default 'pendente'
                check (status in ('pendente','em_andamento','em_revisao','concluido','bloqueado','despriorizado','cancelado')),
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
```

### Dataverse — Tabela: `nid_Tarefa`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Default | Notas |
|---|-------------|-------------|----------------|-------------|---------|-------|
| 1 | Título | `nid_titulo` | Single Line of Text (500) | Sim | — | Primary Name |
| 2 | Sprint | `nid_sprint` | Lookup → nid_Sprint | Sim | — | |
| 3 | Entrega | `nid_entrega` | Lookup → nid_Entrega | Não | — | Substitui entrega_idx |
| 4 | Descrição | `nid_descricao` | Multiple Lines of Text | Não | — | Rich Text |
| 5 | Status | `nid_status` | Choice (nid_entregastatus) | Sim | Pendente | Reutiliza o Choice global |
| 6 | Prioridade | `nid_prioridade` | Choice (nid_prioridade) | Sim | Média | Reutiliza o Choice global |
| 7 | Fase | `nid_fase` | Choice (nid_fase) | Sim | Ideação | Reutiliza o Choice global |
| 8 | Story Points | `nid_storypoints` | Whole Number | Não | — | |
| 9 | Data Início | `nid_datainicio` | Date Only | Não | — | |
| 10 | Data Fim | `nid_datafim` | Date Only | Não | — | |
| 11 | Progresso | `nid_progresso` | Whole Number | Não | 0 | Min: 0, Max: 100 |
| 12 | Criado Por (NID) | `nid_criadopor` | Lookup → nid_Profile | Não | — | |
| 13 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | — | |

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id, sprint_id, entrega_idx, titulo,
         descricao, status, prioridade, fase, story_points,
         data_inicio, data_fim, progresso,
         criado_por AS criado_por_supabase_id,
         created_at, updated_at
  FROM subtarefas
  ORDER BY sprint_id, created_at
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 6: task_members

### Supabase

```sql
create table task_members (
  id         uuid primary key default gen_random_uuid(),
  tarefa_id  uuid references subtarefas(id) on delete cascade,
  profile_id uuid references profiles(id) on delete cascade,
  papel      text default 'executor' check (papel in ('executor','revisor','observador')),
  unique(tarefa_id, profile_id)
);
```

### Dataverse — Tabela: `nid_TarefaMember`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Default |
|---|-------------|-------------|----------------|-------------|---------|
| 1 | Nome | `nid_nome` | Single Line of Text | Sim | Auto |
| 2 | Tarefa | `nid_tarefa` | Lookup → nid_Tarefa | Sim | — |
| 3 | Profile | `nid_profile` | Lookup → nid_Profile | Sim | — |
| 4 | Papel | `nid_papel` | Choice | Sim | Executor |
| 5 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | — |

**Choice: nid_papel**

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Executor | 100000000 |
| 2 | Revisor | 100000001 |
| 3 | Observador | 100000002 |

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id,
         tarefa_id AS tarefa_supabase_id,
         profile_id AS profile_supabase_id,
         papel
  FROM task_members
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 7: task_tags

### Supabase

```sql
create table task_tags (
  id        uuid primary key default gen_random_uuid(),
  tarefa_id uuid references subtarefas(id) on delete cascade,
  tag_id    uuid references tags(id) on delete cascade,
  -- v6: entrega também
  sprint_id   integer,
  entrega_idx integer,
  unique(tarefa_id, tag_id)
);
```

### Dataverse — Tabela: `nid_ItemTag`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Notas |
|---|-------------|-------------|----------------|-------------|-------|
| 1 | Nome | `nid_nome` | Single Line of Text | Sim | Auto |
| 2 | Tarefa | `nid_tarefa` | Lookup → nid_Tarefa | Não | NULL se for tag de entrega |
| 3 | Entrega | `nid_entrega` | Lookup → nid_Entrega | Não | NULL se for tag de tarefa |
| 4 | Tag | `nid_tag` | Lookup → nid_Tag | Sim | |
| 5 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | |

**Alternativa**: Criar um relacionamento N:N nativo entre `nid_Tarefa` e `nid_Tag` (o Dataverse cria a tabela intermediária automaticamente). Porém, como no Supabase a mesma tabela serve para tags de tarefas E entregas, é mais fiel manter como tabela explícita.

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id,
         tarefa_id AS tarefa_supabase_id,
         tag_id AS tag_supabase_id,
         sprint_id, entrega_idx
  FROM task_tags
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 8: checklist_items

### Supabase

```sql
create table checklist_items (
  id         uuid primary key default gen_random_uuid(),
  tarefa_id  uuid references subtarefas(id) on delete cascade,
  texto      text not null,
  concluido  boolean default false,
  ordem      integer default 0,
  created_at timestamptz default now(),
  -- v6: entrega também
  sprint_id   integer,
  entrega_idx integer
);
```

### Dataverse — Tabela: `nid_ChecklistItem`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Default |
|---|-------------|-------------|----------------|-------------|---------|
| 1 | Texto | `nid_texto` | Single Line of Text (500) | Sim | — |
| 2 | Tarefa | `nid_tarefa` | Lookup → nid_Tarefa | Não | — |
| 3 | Entrega | `nid_entrega` | Lookup → nid_Entrega | Não | — |
| 4 | Concluído | `nid_concluido` | Two Options (Yes/No) | Sim | No |
| 5 | Ordem | `nid_ordem` | Whole Number | Não | 0 |
| 6 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | — |

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id,
         tarefa_id AS tarefa_supabase_id,
         sprint_id, entrega_idx,
         texto, concluido, ordem, created_at
  FROM checklist_items
  ORDER BY tarefa_id, ordem
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 9: task_comments

### Supabase

```sql
create table task_comments (
  id          uuid primary key default gen_random_uuid(),
  tarefa_id   uuid references subtarefas(id) on delete cascade,
  sprint_id   integer,
  entrega_idx integer,
  profile_id  uuid references profiles(id) on delete set null,
  texto       text not null,
  created_at  timestamptz default now(),
  -- v9: evento
  evento_id   uuid references calendar_events(id) on delete cascade,
  -- v12: data da ocorrência
  evento_data date
);
```

### Dataverse — Tabela: `nid_Comentario`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Notas |
|---|-------------|-------------|----------------|-------------|-------|
| 1 | Texto | `nid_texto` | Multiple Lines of Text | Sim | Primary Name: truncar para display |
| 2 | Tarefa | `nid_tarefa` | Lookup → nid_Tarefa | Não | |
| 3 | Entrega | `nid_entrega` | Lookup → nid_Entrega | Não | |
| 4 | Evento | `nid_evento` | Lookup → nid_EventoCalendario | Não | |
| 5 | Autor | `nid_autor` | Lookup → nid_Profile | Não | |
| 6 | Evento Data | `nid_eventodata` | Date Only | Não | Para comentários por ocorrência |
| 7 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | |

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id,
         tarefa_id AS tarefa_supabase_id,
         sprint_id, entrega_idx,
         profile_id AS profile_supabase_id,
         texto, created_at,
         evento_id AS evento_supabase_id,
         evento_data
  FROM task_comments
  ORDER BY created_at
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 10: task_attachments

### Supabase

```sql
create table task_attachments (
  id           uuid primary key default gen_random_uuid(),
  tarefa_id    uuid references subtarefas(id) on delete cascade,
  sprint_id    integer,
  entrega_idx  integer,
  profile_id   uuid references profiles(id) on delete set null,
  nome         text not null,
  storage_path text not null,
  url          text not null,
  mime         text,
  tamanho      bigint,
  created_at   timestamptz default now(),
  -- v9: evento
  evento_id    uuid references calendar_events(id) on delete cascade,
  -- v12: data da ocorrência
  evento_data  date,
  -- v17: ideia
  ideia_id     uuid references ideias(id) on delete cascade
);
```

### Dataverse — Tabela: `nid_Anexo`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Notas |
|---|-------------|-------------|----------------|-------------|-------|
| 1 | Nome | `nid_nome` | Single Line of Text (500) | Sim | Primary Name |
| 2 | Tarefa | `nid_tarefa` | Lookup → nid_Tarefa | Não | |
| 3 | Entrega | `nid_entrega` | Lookup → nid_Entrega | Não | |
| 4 | Evento | `nid_evento` | Lookup → nid_EventoCalendario | Não | |
| 5 | Ideia | `nid_ideia` | Lookup → nid_Ideia | Não | |
| 6 | Autor | `nid_autor` | Lookup → nid_Profile | Não | |
| 7 | Arquivo | `nid_arquivo` | File | Não | Até 128MB. Migrar os arquivos do Supabase Storage |
| 8 | URL Original | `nid_url` | Single Line of Text (2000) | Não | URL do Supabase (manter para referência) |
| 9 | Storage Path | `nid_storagepath` | Single Line of Text (1000) | Não | Path original no Supabase |
| 10 | MIME | `nid_mime` | Single Line of Text (100) | Não | |
| 11 | Tamanho | `nid_tamanho` | Whole Number (Big) | Não | Em bytes |
| 12 | Evento Data | `nid_eventodata` | Date Only | Não | |
| 13 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | |

**Migração de arquivos**: Os arquivos estão no Supabase Storage (bucket `task-files`). Opções:
1. **Manter URLs**: Se o Supabase continuar ativo, manter as URLs atuais na coluna `nid_url`
2. **Migrar para SharePoint**: Baixar do Supabase, subir para SharePoint, atualizar URLs
3. **Migrar para Dataverse File**: Upload direto na coluna `nid_arquivo` (até 128MB/arquivo)

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id,
         tarefa_id AS tarefa_supabase_id,
         sprint_id, entrega_idx,
         profile_id AS profile_supabase_id,
         nome, storage_path, url, mime, tamanho, created_at,
         evento_id AS evento_supabase_id,
         evento_data,
         ideia_id AS ideia_supabase_id
  FROM task_attachments
  ORDER BY created_at
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 11: sprint_reviews

### Supabase

```sql
create table sprint_reviews (
  id                  uuid primary key default gen_random_uuid(),
  sprint_id           integer not null,
  entregas_realizadas text,
  riscos_bloqueadores text,
  proximas_acoes      text,
  percentual_entregue integer,
  velocidade_pontos   integer,
  nps_equipe          integer,
  data_realizacao     date,
  updated_at          timestamptz default now(),
  -- v13: múltiplas reviews por sprint
  resumo_dashboard    jsonb,
  observacoes         text,
  criado_por          uuid references profiles(id) on delete set null
);
```

### Dataverse — Tabela: `nid_SprintReview`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Notas |
|---|-------------|-------------|----------------|-------------|-------|
| 1 | Nome | `nid_nome` | Single Line of Text | Sim | "Review Sprint {N} — {data}" |
| 2 | Sprint | `nid_sprint` | Lookup → nid_Sprint | Sim | |
| 3 | Entregas Realizadas | `nid_entregasrealizadas` | Multiple Lines of Text | Não | |
| 4 | Riscos e Bloqueadores | `nid_riscosbloqueadores` | Multiple Lines of Text | Não | |
| 5 | Próximas Ações | `nid_proximasacoes` | Multiple Lines of Text | Não | |
| 6 | % Entregue | `nid_percentualentregue` | Whole Number | Não | 0-100 |
| 7 | Velocidade (pontos) | `nid_velocidadepontos` | Whole Number | Não | |
| 8 | NPS Equipe | `nid_npsequipe` | Whole Number | Não | 0-10 |
| 9 | Data Realização | `nid_datarealizacao` | Date Only | Não | |
| 10 | Resumo Dashboard | `nid_resumodashboard` | Multiple Lines of Text | Não | JSON string |
| 11 | Observações | `nid_observacoes` | Multiple Lines of Text | Não | |
| 12 | Criado Por | `nid_criadopor` | Lookup → nid_Profile | Não | |
| 13 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | |

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id, sprint_id,
         entregas_realizadas, riscos_bloqueadores, proximas_acoes,
         percentual_entregue, velocidade_pontos, nps_equipe,
         data_realizacao, resumo_dashboard::text,
         observacoes, criado_por AS criado_por_supabase_id, updated_at
  FROM sprint_reviews
  ORDER BY sprint_id, data_realizacao
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 12: sprint_review_items

### Supabase

```sql
create table sprint_review_items (
  id          uuid primary key default gen_random_uuid(),
  review_id   uuid references sprint_reviews(id) on delete cascade,
  sprint_id   integer not null,
  entrega_idx integer not null,
  disposicao  text not null default 'concluido'
              check (disposicao in ('concluido','remanejado','fora','pendente','em_andamento')),
  destino_sprint integer,
  observacao  text,
  created_at  timestamptz default now()
);
```

### Dataverse — Tabela: `nid_ReviewItem`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Default |
|---|-------------|-------------|----------------|-------------|---------|
| 1 | Nome | `nid_nome` | Single Line of Text | Sim | Auto |
| 2 | Review | `nid_review` | Lookup → nid_SprintReview | Sim | — |
| 3 | Entrega | `nid_entrega` | Lookup → nid_Entrega | Não | — |
| 4 | Disposição | `nid_disposicao` | Choice | Sim | Concluído |
| 5 | Sprint Destino | `nid_sprintdestino` | Lookup → nid_Sprint | Não | — |
| 6 | Observação | `nid_observacao` | Multiple Lines of Text | Não | — |
| 7 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | — |

**Choice: nid_disposicao**

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Concluído | 100000000 |
| 2 | Remanejado | 100000001 |
| 3 | Fora | 100000002 |
| 4 | Pendente | 100000003 |
| 5 | Em Andamento | 100000004 |

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id,
         review_id AS review_supabase_id,
         sprint_id, entrega_idx,
         disposicao, destino_sprint,
         observacao, created_at
  FROM sprint_review_items
  ORDER BY review_id, sprint_id, entrega_idx
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 13: calendar_events

### Supabase

```sql
create table calendar_events (
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
```

### Dataverse — Tabela: `nid_EventoCalendario`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Default | Notas |
|---|-------------|-------------|----------------|-------------|---------|-------|
| 1 | Título | `nid_titulo` | Single Line of Text (300) | Sim | — | Primary Name |
| 2 | Tipo | `nid_tipo` | Choice | Sim | Reunião | |
| 3 | Descrição | `nid_descricao` | Multiple Lines of Text | Não | — | |
| 4 | Data | `nid_data` | Date Only | Sim | — | |
| 5 | Hora Início | `nid_horainicio` | Single Line of Text (10) | Não | — | "HH:MM" |
| 6 | Hora Fim | `nid_horafim` | Single Line of Text (10) | Não | — | "HH:MM" |
| 7 | Local | `nid_local` | Single Line of Text (300) | Não | — | |
| 8 | Duração (min) | `nid_duracaomin` | Whole Number | Não | — | |
| 9 | Recorrente | `nid_recorrente` | Two Options (Yes/No) | Sim | No | |
| 10 | Recorrência | `nid_recorrencia` | Choice | Não | — | |
| 11 | Cor | `nid_cor` | Single Line of Text (20) | Não | #2B6AFF | |
| 12 | Sprint | `nid_sprint` | Lookup → nid_Sprint | Não | — | |
| 13 | Criado Por | `nid_criadopor` | Lookup → nid_Profile | Não | — | |
| 14 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | — |

**Choice: nid_eventotipo**

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Reunião | 100000000 |
| 2 | Tarefa | 100000001 |
| 3 | Atividade | 100000002 |
| 4 | Weekly | 100000003 |
| 5 | Outro | 100000004 |

**Choice: nid_recorrencia**

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Semanal | 100000000 |
| 2 | Quinzenal | 100000001 |
| 3 | Mensal | 100000002 |
| 4 | Nenhuma | 100000003 |

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id, tipo, titulo, descricao,
         data, hora_inicio::text, hora_fim::text,
         local, duracao_min, recorrente, recorrencia,
         cor, sprint_id,
         criado_por AS criado_por_supabase_id,
         created_at
  FROM calendar_events
  ORDER BY data
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 14: event_members

### Supabase

```sql
create table event_members (
  id         uuid primary key default gen_random_uuid(),
  evento_id  uuid references calendar_events(id) on delete cascade,
  profile_id uuid references profiles(id) on delete cascade,
  unique(evento_id, profile_id)
);
```

### Dataverse — Tabela: `nid_EventoMember`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório |
|---|-------------|-------------|----------------|-------------|
| 1 | Nome | `nid_nome` | Single Line of Text | Sim |
| 2 | Evento | `nid_evento` | Lookup → nid_EventoCalendario | Sim |
| 3 | Profile | `nid_profile` | Lookup → nid_Profile | Sim |
| 4 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não |

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id,
         evento_id AS evento_supabase_id,
         profile_id AS profile_supabase_id
  FROM event_members
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 15: audit_log

### Supabase

```sql
create table audit_log (
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
```

### Dataverse — Tabela: `nid_AuditLog`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Notas |
|---|-------------|-------------|----------------|-------------|-------|
| 1 | Resumo | `nid_resumo` | Single Line of Text (500) | Sim | Primary Name |
| 2 | Ação | `nid_acao` | Single Line of Text (100) | Sim | |
| 3 | Tipo Entidade | `nid_tipoentidade` | Single Line of Text (100) | Sim | |
| 4 | ID Entidade | `nid_identidade` | Single Line of Text (100) | Não | |
| 5 | Sprint | `nid_sprint` | Lookup → nid_Sprint | Não | |
| 6 | Profile | `nid_profile` | Lookup → nid_Profile | Não | |
| 7 | Detalhes | `nid_detalhes` | Multiple Lines of Text | Não | JSON string |
| 8 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | |

> **Nota**: O Dataverse tem auditoria nativa (habilitável por tabela). Considere usar a auditoria nativa para novos registros e manter esta tabela apenas para o histórico migrado.

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id,
         profile_id AS profile_supabase_id,
         action, entity_type, entity_id,
         sprint_id, summary,
         details::text AS details,
         created_at
  FROM audit_log
  ORDER BY created_at
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 16: pa_items

### Supabase

```sql
create table pa_items (
  id           uuid primary key default gen_random_uuid(),
  pa_idx       integer not null unique,
  status       text,
  sprint_id    integer,
  vinculo_tipo text check (vinculo_tipo in ('entrega','tarefa') or vinculo_tipo is null),
  entrega_ref  text,
  tarefa_id    uuid references subtarefas(id) on delete set null,
  obs          text,
  updated_at   timestamptz default now()
);
```

### Dataverse — Tabela: `nid_PlanoAcaoItem`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Notas |
|---|-------------|-------------|----------------|-------------|-------|
| 1 | Nome | `nid_nome` | Single Line of Text (300) | Sim | "PA {pa_idx} — {subação título}" |
| 2 | PA Idx | `nid_paidx` | Whole Number | Sim | Unique (Alternate Key) |
| 3 | Status | `nid_status` | Single Line of Text (50) | Não | Override do catálogo |
| 4 | Sprint | `nid_sprint` | Lookup → nid_Sprint | Não | |
| 5 | Vínculo Tipo | `nid_vinculotipo` | Choice | Não | |
| 6 | Entrega Ref | `nid_entregaref` | Single Line of Text (50) | Não | "sid-idx" |
| 7 | Tarefa | `nid_tarefa` | Lookup → nid_Tarefa | Não | |
| 8 | Observação | `nid_obs` | Multiple Lines of Text | Não | |
| 9 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | |

**Choice: nid_vinculotipo**

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Entrega | 100000000 |
| 2 | Tarefa | 100000001 |

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id, pa_idx, status, sprint_id,
         vinculo_tipo, entrega_ref,
         tarefa_id AS tarefa_supabase_id,
         obs, updated_at
  FROM pa_items
  ORDER BY pa_idx
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 17: pa_om_status

### Supabase

```sql
create table pa_om_status (
  id              uuid primary key default gen_random_uuid(),
  om_id           integer not null unique,
  descontinuado   boolean default false,
  justificativa   text,
  descontinuado_por uuid references profiles(id) on delete set null,
  descontinuado_em timestamptz,
  updated_at      timestamptz default now()
);
```

### Dataverse — Tabela: `nid_OMStatus`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Notas |
|---|-------------|-------------|----------------|-------------|-------|
| 1 | Nome | `nid_nome` | Single Line of Text | Sim | "OM {om_id}" |
| 2 | OM ID | `nid_omid` | Whole Number | Sim | Unique (Alternate Key) |
| 3 | Descontinuado | `nid_descontinuado` | Two Options (Yes/No) | Sim | Default: No |
| 4 | Justificativa | `nid_justificativa` | Multiple Lines of Text | Não | |
| 5 | Descontinuado Por | `nid_descontinuadopor` | Lookup → nid_Profile | Não | |
| 6 | Descontinuado Em | `nid_descontinuadoem` | Date and Time | Não | |
| 7 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | |

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id, om_id, descontinuado,
         justificativa,
         descontinuado_por AS descontinuado_por_supabase_id,
         descontinuado_em, updated_at
  FROM pa_om_status
  ORDER BY om_id
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 18: ideias

### Supabase

```sql
create table ideias (
  id          uuid primary key default gen_random_uuid(),
  tipo        text not null default 'ideia'
              check (tipo in ('ideia','embrionario','curso','workshop')),
  titulo      text not null,
  descricao   text,
  link        text,
  tags_text   text,
  status      text not null default 'rascunho'
              check (status in ('rascunho','compartilhado','em_avaliacao','aprovado','arquivado')),
  autor_id    uuid references profiles(id) on delete set null,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);
```

### Dataverse — Tabela: `nid_Ideia`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Default |
|---|-------------|-------------|----------------|-------------|---------|
| 1 | Título | `nid_titulo` | Single Line of Text (300) | Sim | — |
| 2 | Tipo | `nid_tipo` | Choice | Sim | Ideia |
| 3 | Descrição | `nid_descricao` | Multiple Lines of Text | Não | — |
| 4 | Link | `nid_link` | Single Line of Text (2000) | Não | — |
| 5 | Tags (texto) | `nid_tagstext` | Single Line of Text (500) | Não | — |
| 6 | Status | `nid_status` | Choice | Sim | Rascunho |
| 7 | Autor | `nid_autor` | Lookup → nid_Profile | Não | — |
| 8 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | — |

**Choice: nid_ideiatipo**

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Ideia | 100000000 |
| 2 | Embrionário | 100000001 |
| 3 | Curso | 100000002 |
| 4 | Workshop | 100000003 |

**Choice: nid_ideiastatus**

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Rascunho | 100000000 |
| 2 | Compartilhado | 100000001 |
| 3 | Em Avaliação | 100000002 |
| 4 | Aprovado | 100000003 |
| 5 | Arquivado | 100000004 |

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id, tipo, titulo, descricao,
         link, tags_text, status,
         autor_id AS autor_supabase_id,
         created_at, updated_at
  FROM ideias
  ORDER BY created_at
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 19: riscos

### Supabase

```sql
create table riscos (
  id             uuid primary key default gen_random_uuid(),
  codigo         text not null unique,
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
```

### Dataverse — Tabela: `nid_Risco`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Default | Notas |
|---|-------------|-------------|----------------|-------------|---------|-------|
| 1 | Título | `nid_titulo` | Single Line of Text (500) | Sim | — | Primary Name |
| 2 | Código | `nid_codigo` | Single Line of Text (50) | Sim | — | Alternate Key (unique) |
| 3 | Abordagem | `nid_abordagem` | Choice | Sim | Operacional | |
| 4 | Ciclo | `nid_ciclo` | Single Line of Text (10) | Não | 2026 | |
| 5 | Status | `nid_status` | Choice | Não | Manutenção | |
| 6 | Nível Residual | `nid_nivelresidual` | Choice | Não | — | |
| 7 | Plano de Ação | `nid_planoacao` | Multiple Lines of Text | Não | — | |
| 8 | Observações | `nid_observacoes` | Multiple Lines of Text | Não | — | |
| 9 | Vínculo Tipo | `nid_vinculotipo` | Choice (nid_vinculotipo) | Não | — | Reutiliza |
| 10 | Vínculo Ref | `nid_vinculoref` | Single Line of Text (50) | Não | — | |
| 11 | Tarefa | `nid_tarefa` | Lookup → nid_Tarefa | Não | — | |
| 12 | Sprint | `nid_sprint` | Lookup → nid_Sprint | Não | — | |
| 13 | Criado Por | `nid_criadopor` | Lookup → nid_Profile | Não | — | |
| 14 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | — |

**Choice: nid_riscoabordagem**

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Operacional | 100000000 |
| 2 | Organizacionais | 100000001 |

**Choice: nid_riscostatus**

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Manutenção | 100000000 |
| 2 | Mitigação | 100000001 |
| 3 | Aceito | 100000002 |
| 4 | Transferido | 100000003 |
| 5 | Eliminado | 100000004 |

**Choice: nid_nivelresidual**

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Baixo | 100000000 |
| 2 | Moderado | 100000001 |
| 3 | Alto | 100000002 |
| 4 | Extremo | 100000003 |

### Tabela filha: `nid_RiscoControle`

No Supabase, `controles` é JSONB dentro da tabela `riscos`. No Dataverse, criar tabela separada:

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório |
|---|-------------|-------------|----------------|-------------|
| 1 | Descrição | `nid_descricao` | Single Line of Text (500) | Sim |
| 2 | Risco | `nid_risco` | Lookup → nid_Risco | Sim |
| 3 | Código | `nid_codigo` | Single Line of Text (20) | Não |

> **Migração do JSONB**: Para cada risco, iterar o array `controles` e criar um registro em `nid_RiscoControle` para cada item.

### Exportação Supabase

```sql
-- Riscos (dados principais)
COPY (
  SELECT id AS supabase_id, codigo, titulo, abordagem, ciclo,
         status, nivel_residual, plano_acao, observacoes,
         vinculo_tipo, vinculo_ref,
         tarefa_id AS tarefa_supabase_id,
         sprint_id,
         created_by AS created_by_supabase_id,
         created_at, updated_at
  FROM riscos
  ORDER BY abordagem, codigo
) TO STDOUT WITH CSV HEADER;

-- Controles (explode JSONB → linhas)
COPY (
  SELECT
    r.id AS risco_supabase_id,
    r.codigo AS risco_codigo,
    c->>'codigo' AS controle_codigo,
    c->>'descricao' AS controle_descricao
  FROM riscos r,
       jsonb_array_elements(r.controles) AS c
  ORDER BY r.codigo
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela 20: reminder_log

### Supabase

```sql
create table reminder_log (
  id           uuid primary key default gen_random_uuid(),
  tipo         text not null,
  destinatario text,
  conteudo     text,
  status       text default 'enviado',
  error_msg    text,
  created_at   timestamptz default now()
);
```

### Dataverse — Tabela: `nid_ReminderLog`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Default |
|---|-------------|-------------|----------------|-------------|---------|
| 1 | Resumo | `nid_resumo` | Single Line of Text (300) | Sim | Auto |
| 2 | Tipo | `nid_tipo` | Choice | Sim | — |
| 3 | Destinatário | `nid_destinatario` | Single Line of Text (500) | Não | — |
| 4 | Conteúdo | `nid_conteudo` | Multiple Lines of Text | Não | — |
| 5 | Status | `nid_statusenvio` | Choice | Sim | Enviado |
| 6 | Erro | `nid_erro` | Multiple Lines of Text | Não | — |
| 7 | Supabase ID | `nid_supabaseid` | Single Line of Text (50) | Não | — |

**Choice: nid_lembretecanalc**

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Teams | 100000000 |
| 2 | Email | 100000001 |

**Choice: nid_lembretestatusenvio**

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Enviado | 100000000 |
| 2 | Erro | 100000001 |

### Exportação Supabase

```sql
COPY (
  SELECT id AS supabase_id, tipo, destinatario, conteudo, status, error_msg, created_at
  FROM reminder_log
  ORDER BY created_at
) TO STDOUT WITH CSV HEADER;
```

---

## Tabela Extra: nid_Sprint (NOVA)

No Supabase, sprints não têm tabela — são números inteiros. Para o Dataverse, criar a tabela:

### Dataverse — Tabela: `nid_Sprint`

| # | Nome Display | Nome Lógico | Tipo Dataverse | Obrigatório | Notas |
|---|-------------|-------------|----------------|-------------|-------|
| 1 | Nome | `nid_nome` | Single Line of Text (200) | Sim | "Sprint 1 — Jun/Jul 2026" |
| 2 | Número | `nid_numero` | Whole Number | Sim | Alternate Key (unique) |
| 3 | Data Início | `nid_datainicio` | Date Only | Sim | |
| 4 | Data Fim | `nid_datafim` | Date Only | Sim | |
| 5 | Status | `nid_status` | Choice | Sim | |

**Choice: nid_sprintstatus**

| Valor | Label | Código |
|-------|-------|--------|
| 1 | Planejada | 100000000 |
| 2 | Em Andamento | 100000001 |
| 3 | Finalizada | 100000002 |

**Dados iniciais** (extrair do catálogo JS no index.html):

| Número | Nome | Início | Fim | Status |
|--------|------|--------|-----|--------|
| 1 | Sprint 1 — Jun/Jul 2026 | 2026-06-01 | 2026-07-15 | Finalizada |
| 2 | Sprint 2 — Jul/Ago 2026 | 2026-07-16 | 2026-08-31 | Planejada |
| 3 | Sprint 3 — Set/Out 2026 | 2026-09-01 | 2026-10-15 | Planejada |
| ... | (extrair restante do catálogo) | ... | ... | Planejada |

---

## Resumo dos Choice Globais

Crie estes Choice como **Global Option Sets** para reutilizar em várias tabelas:

| Choice | Usado em | Opções |
|--------|----------|--------|
| `nid_status` | Entrega, Tarefa | Pendente, Em Andamento, Em Revisão, Concluído, Bloqueado, Despriorizado, Cancelado |
| `nid_prioridade` | Entrega, Tarefa | Crítica, Alta, Média, Baixa |
| `nid_fase` | Entrega, Tarefa | Ideação, Business Case, Planejamento, Execução, Homologação, Implantação, Encerramento |
| `nid_papel` | TarefaMember | Executor, Revisor, Observador |
| `nid_vinculotipo` | PA Items, Riscos | Entrega, Tarefa |

---

## Scripts de Exportação Supabase

### Script Completo (executar no SQL Editor do Supabase)

```sql
-- ============================================
-- EXPORTAÇÃO COMPLETA PARA MIGRAÇÃO
-- Execute cada bloco separadamente e salve como CSV
-- ============================================

-- 1. profiles
SELECT id, email, nome, iniciais, cor, area, cargo, ativo, tipo,
       foto_url, bio, senioridade, habilidades::text, projetos_liderados, created_at
FROM profiles ORDER BY created_at;

-- 2. tags
SELECT id, nome, cor, tipo FROM tags ORDER BY tipo, nome;

-- 3. sprint_entregas
SELECT id, sprint_id, entrega_idx, status, obs, data_inicio, data_fim,
       descricao, prioridade, fase, story_points, progresso, updated_at
FROM sprint_entregas ORDER BY sprint_id, entrega_idx;

-- 4. entrega_members
SELECT id, sprint_id, entrega_idx, profile_id FROM entrega_members;

-- 5. subtarefas
SELECT id, sprint_id, entrega_idx, titulo, descricao, status, prioridade,
       fase, story_points, data_inicio, data_fim, progresso, criado_por,
       created_at, updated_at
FROM subtarefas ORDER BY sprint_id, created_at;

-- 6. task_members
SELECT id, tarefa_id, profile_id, papel FROM task_members;

-- 7. task_tags
SELECT id, tarefa_id, tag_id, sprint_id, entrega_idx FROM task_tags;

-- 8. checklist_items
SELECT id, tarefa_id, sprint_id, entrega_idx, texto, concluido, ordem, created_at
FROM checklist_items ORDER BY tarefa_id, ordem;

-- 9. task_comments
SELECT id, tarefa_id, sprint_id, entrega_idx, profile_id, texto,
       created_at, evento_id, evento_data
FROM task_comments ORDER BY created_at;

-- 10. task_attachments
SELECT id, tarefa_id, sprint_id, entrega_idx, profile_id, nome,
       storage_path, url, mime, tamanho, created_at, evento_id,
       evento_data, ideia_id
FROM task_attachments ORDER BY created_at;

-- 11. sprint_reviews
SELECT id, sprint_id, entregas_realizadas, riscos_bloqueadores,
       proximas_acoes, percentual_entregue, velocidade_pontos,
       nps_equipe, data_realizacao, resumo_dashboard::text,
       observacoes, criado_por, updated_at
FROM sprint_reviews ORDER BY sprint_id;

-- 12. sprint_review_items
SELECT id, review_id, sprint_id, entrega_idx, disposicao,
       destino_sprint, observacao, created_at
FROM sprint_review_items ORDER BY review_id;

-- 13. calendar_events
SELECT id, tipo, titulo, descricao, data, hora_inicio::text,
       hora_fim::text, local, duracao_min, recorrente, recorrencia,
       cor, sprint_id, criado_por, created_at
FROM calendar_events ORDER BY data;

-- 14. event_members
SELECT id, evento_id, profile_id FROM event_members;

-- 15. audit_log
SELECT id, profile_id, action, entity_type, entity_id, sprint_id,
       summary, details::text, created_at
FROM audit_log ORDER BY created_at;

-- 16. pa_items
SELECT id, pa_idx, status, sprint_id, vinculo_tipo, entrega_ref,
       tarefa_id, obs, updated_at
FROM pa_items ORDER BY pa_idx;

-- 17. pa_om_status
SELECT id, om_id, descontinuado, justificativa,
       descontinuado_por, descontinuado_em, updated_at
FROM pa_om_status ORDER BY om_id;

-- 18. ideias
SELECT id, tipo, titulo, descricao, link, tags_text, status,
       autor_id, created_at, updated_at
FROM ideias ORDER BY created_at;

-- 19. riscos
SELECT id, codigo, titulo, abordagem, ciclo, status,
       nivel_residual, plano_acao, observacoes,
       vinculo_tipo, vinculo_ref, tarefa_id, sprint_id,
       created_by, created_at, updated_at
FROM riscos ORDER BY abordagem, codigo;

-- 19b. riscos_controles (explode JSONB)
SELECT r.id AS risco_id, r.codigo AS risco_codigo,
       c->>'codigo' AS controle_codigo,
       c->>'descricao' AS controle_descricao
FROM riscos r, jsonb_array_elements(r.controles) AS c
ORDER BY r.codigo;

-- 20. reminder_log
SELECT id, tipo, destinatario, conteudo, status, error_msg, created_at
FROM reminder_log ORDER BY created_at;
```

---

## Procedimento de Importação

### Passo 1 — Exportar CSVs do Supabase

1. Abra o **SQL Editor** do Supabase
2. Execute cada query acima, uma por vez
3. Clique **Export** → **CSV** para cada resultado
4. Nomeie: `01_profiles.csv`, `02_tags.csv`, ... `20_reminder_log.csv`

### Passo 2 — Criar as tabelas no Dataverse

Siga a ordem da seção "Ordem de Migração". Para cada tabela:
1. make.powerapps.com → Tabelas → + Nova tabela
2. Crie colunas conforme as especificações acima
3. Crie os Choices Globais PRIMEIRO (antes das tabelas que os usam)
4. Crie as tabelas independentes PRIMEIRO (profiles, tags, nid_Sprint)

### Passo 3 — Importar dados (via Power Automate ou manualmente)

**Opção A — Import nativo do Dataverse:**
1. Na tabela, clique **Importar** → **Importar dados**
2. Selecione **Texto/CSV** como fonte
3. Faça upload do CSV
4. **Mapeie as colunas** (atenção especial nos Lookups)
5. Para Lookups: mapear `profile_supabase_id` → procurar o GUID no Dataverse usando a coluna `nid_supabaseid` do Profile

**Opção B — Power Automate (recomendado para Lookups):**

```
Fluxo: Importar Subtarefas
  │
  ▼
Gatilho: Manualmente
  │
  ▼
Ação: Obter conteúdo do arquivo (OneDrive/SharePoint)
  └── Arquivo: 05_subtarefas.csv
  │
  ▼
Ação: Criar tabela CSV
  │
  ▼
Para cada linha:
  │
  ├── Ação: Obter linhas — nid_Profile
  │   └── Filtro: nid_supabaseid eq '{criado_por}'
  │
  ├── Ação: Obter linhas — nid_Sprint
  │   └── Filtro: nid_numero eq {sprint_id}
  │
  └── Ação: Adicionar nova linha — nid_Tarefa
      ├── nid_titulo: {titulo}
      ├── nid_sprint: {Sprint.id do lookup}
      ├── nid_status: {mapear string → Choice code}
      ├── nid_criadopor: {Profile.id do lookup}
      ├── nid_supabaseid: {id original}
      └── ... demais campos
```

### Passo 4 — Ordem de importação

```
1.  nid_Sprint        (dados do catálogo JS)
2.  nid_Profile       (01_profiles.csv)
3.  nid_Tag           (02_tags.csv)
4.  nid_Entrega       (03_sprint_entregas.csv) → Lookup Sprint
5.  nid_Tarefa        (05_subtarefas.csv) → Lookup Sprint, Profile, Entrega
6.  nid_EventoCalendario (13_calendar_events.csv) → Lookup Sprint, Profile
7.  nid_Ideia         (18_ideias.csv) → Lookup Profile
8.  nid_Risco         (19_riscos.csv) → Lookup Profile, Tarefa, Sprint
9.  nid_RiscoControle (19b_riscos_controles.csv) → Lookup Risco
10. nid_SprintReview  (11_sprint_reviews.csv) → Lookup Sprint, Profile
11. nid_PlanoAcaoItem (16_pa_items.csv) → Lookup Sprint, Tarefa
12. nid_OMStatus      (17_pa_om_status.csv) → Lookup Profile
13. nid_EntregaMember (04_entrega_members.csv) → Lookup Entrega, Profile
14. nid_TarefaMember  (06_task_members.csv) → Lookup Tarefa, Profile
15. nid_ItemTag       (07_task_tags.csv) → Lookup Tarefa/Entrega, Tag
16. nid_ChecklistItem (08_checklist_items.csv) → Lookup Tarefa/Entrega
17. nid_Comentario    (09_task_comments.csv) → Lookup Tarefa/Entrega/Evento, Profile
18. nid_Anexo         (10_task_attachments.csv) → Lookup Tarefa/Entrega/Evento/Ideia, Profile
19. nid_EventoMember  (14_event_members.csv) → Lookup Evento, Profile
20. nid_ReviewItem    (12_sprint_review_items.csv) → Lookup Review, Entrega
21. nid_AuditLog      (15_audit_log.csv) → Lookup Sprint, Profile
22. nid_ReminderLog   (20_reminder_log.csv) → Sem FK
```

---

## Validação Pós-Migração

### Queries de contagem (executar em ambos)

| Tabela | Query Supabase | Query Dataverse (Power Fx) |
|--------|---------------|---------------------------|
| profiles | `SELECT count(*) FROM profiles` | `CountRows(nid_Profiles)` |
| tags | `SELECT count(*) FROM tags` | `CountRows(nid_Tags)` |
| sprint_entregas | `SELECT count(*) FROM sprint_entregas` | `CountRows(nid_Entregas)` |
| subtarefas | `SELECT count(*) FROM subtarefas` | `CountRows(nid_Tarefas)` |
| checklist_items | `SELECT count(*) FROM checklist_items` | `CountRows(nid_ChecklistItems)` |
| task_comments | `SELECT count(*) FROM task_comments` | `CountRows(nid_Comentarios)` |
| task_attachments | `SELECT count(*) FROM task_attachments` | `CountRows(nid_Anexos)` |
| calendar_events | `SELECT count(*) FROM calendar_events` | `CountRows(nid_EventosCalendario)` |
| riscos | `SELECT count(*) FROM riscos` | `CountRows(nid_Riscos)` |
| pa_items | `SELECT count(*) FROM pa_items` | `CountRows(nid_PlanoAcaoItems)` |
| ideias | `SELECT count(*) FROM ideias` | `CountRows(nid_Ideias)` |
| audit_log | `SELECT count(*) FROM audit_log` | `CountRows(nid_AuditLogs)` |

### Checklist de Validação

- [ ] Contagem de registros igual em todas as tabelas
- [ ] Todos os Lookups resolvem corretamente (sem registros órfãos)
- [ ] Choice values mapeados corretamente (status, prioridade, fase)
- [ ] Datas preservadas sem offset de timezone
- [ ] Campos de texto multilinha mantêm quebras de linha
- [ ] JSONB de controles de riscos explodido em registros corretos
- [ ] Sprint 1 (Finalizada) e Sprint 2 (Planejada) com dados intactos
- [ ] Arquivos do Storage migraram ou URLs permanecem acessíveis
- [ ] Auditoria histórica preservada
- [ ] Security Roles atribuídos corretamente

---

## Diagrama de Relacionamentos

```
nid_Sprint (NOVA)
 ├──< nid_Entrega (N:1)
 │    ├──< nid_EntregaMember (N:1)
 │    ├──< nid_ItemTag (N:1)
 │    ├──< nid_ChecklistItem (N:1)
 │    ├──< nid_Comentario (N:1)
 │    ├──< nid_Anexo (N:1)
 │    └──< nid_ReviewItem (N:1)
 ├──< nid_Tarefa (N:1)
 │    ├──< nid_TarefaMember (N:1)
 │    ├──< nid_ItemTag (N:1)
 │    ├──< nid_ChecklistItem (N:1)
 │    ├──< nid_Comentario (N:1)
 │    └──< nid_Anexo (N:1)
 ├──< nid_SprintReview (N:1)
 │    └──< nid_ReviewItem (N:1)
 ├──< nid_EventoCalendario (N:1)
 │    ├──< nid_EventoMember (N:1)
 │    ├──< nid_Comentario (N:1)
 │    └──< nid_Anexo (N:1)
 ├──< nid_PlanoAcaoItem (N:1)
 ├──< nid_Risco (N:1)
 │    └──< nid_RiscoControle (N:1)
 └──< nid_AuditLog (N:1)

nid_Profile
 ├──< nid_TarefaMember (N:1)
 ├──< nid_EntregaMember (N:1)
 ├──< nid_EventoMember (N:1)
 ├──< nid_Comentario.autor (N:1)
 ├──< nid_Anexo.autor (N:1)
 ├──< nid_Tarefa.criado_por (N:1)
 ├──< nid_EventoCalendario.criado_por (N:1)
 ├──< nid_SprintReview.criado_por (N:1)
 ├──< nid_Risco.criado_por (N:1)
 ├──< nid_Ideia.autor (N:1)
 ├──< nid_OMStatus.descontinuado_por (N:1)
 └──< nid_AuditLog (N:1)

nid_Tag
 └──< nid_ItemTag (N:1)

nid_Ideia
 └──< nid_Anexo (N:1)
```

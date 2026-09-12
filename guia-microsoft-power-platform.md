# NID/COBEN Agile Board — Guia de Reconstrução na Microsoft Power Platform

## Visão Geral da Migração

| Componente Atual | Equivalente Microsoft |
|-----------------|----------------------|
| Supabase (PostgreSQL) | **Dataverse** (banco de dados) |
| Supabase Auth | **Microsoft Entra ID** (Azure AD) |
| Supabase Storage | **SharePoint / OneDrive** |
| index.html (frontend) | **Power Apps** (Canvas App) |
| JavaScript vanilla | **Power Fx** (fórmulas do Power Apps) |
| API Claude (IA) | **Copilot Studio + Azure OpenAI** |
| Teams Webhook | **Power Automate + Teams connector** |
| Resend (e-mail) | **Power Automate + Outlook connector** |
| Edge Function (pg_cron) | **Power Automate (fluxos agendados)** |
| Netlify (deploy) | **Teams Tab / SharePoint** (hospedagem) |
| Gráficos JS | **Power BI** (dashboards) |

---

## FASE 1 — Configurar o Ambiente (Dia 1)

### 1.1 Obter Licenças

Verifique com o TI da FUNCEF quais licenças Microsoft 365 vocês já possuem:

| Licença | O que libera |
|---------|-------------|
| **Microsoft 365 E3/E5** | Teams, SharePoint, Outlook, OneDrive |
| **Power Apps per user** (~R$ 100/mês/user) | Power Apps, Dataverse (250MB), Power Automate |
| **Power Apps per app** (~R$ 25/mês/app/user) | 1 app específico por usuário |
| **Power BI Pro** (~R$ 50/mês/user) | Dashboards compartilhados |
| **Power Automate per user** (~R$ 75/mês/user) | Fluxos ilimitados |
| **Copilot Studio** (adicional) | Bot com IA |

> **Dica FUNCEF**: Se vocês já têm M365 E3/E5, o Teams, SharePoint e Outlook já estão inclusos. O que falta é a licença de Power Apps/Automate. Peça ao TI para ativar o **Power Apps Developer Plan** (gratuito para desenvolvimento) enquanto não tem a licença oficial.

### 1.2 Criar o Ambiente no Power Platform

1. Acesse **admin.powerplatform.microsoft.com**
2. **Ambientes** → **+ Novo**
3. Preencha:
   - Nome: `NID-COBEN-Producao`
   - Tipo: **Produção** (ou Sandbox para testes)
   - Região: **Brasil**
   - Criar banco de dados: **Sim**
   - Idioma: Português (Brasil)
   - Moeda: BRL
4. Clique **Salvar**
5. Aguarde ~5 min para provisionar

> Crie também um ambiente `NID-COBEN-Dev` (tipo Sandbox) para desenvolvimento sem risco.

### 1.3 Configurar Grupos de Segurança no Entra ID

1. Acesse **entra.microsoft.com** → Grupos
2. Crie os grupos:
   - `NID-Admins` — Daniela e gestores
   - `NID-Integrantes` — Equipe do NID
   - `NID-Visitantes` — Acesso somente leitura
3. Adicione os membros em cada grupo
4. No Power Platform Admin Center, associe o grupo `NID-Integrantes` ao ambiente

---

## FASE 2 — Modelagem de Dados no Dataverse (Dia 2-3)

### 2.1 Entender o Dataverse

O Dataverse é o banco de dados da Microsoft. Conceitos:

| Supabase/SQL | Dataverse |
|-------------|-----------|
| Tabela | **Tabela** (Table) |
| Coluna | **Coluna** (Column) |
| Linha | **Linha** (Row) |
| Foreign Key | **Lookup** (relacionamento) |
| RLS Policy | **Segurança por nível de linha** (Column/Row security) |
| JSONB | **Tabela filho** ou coluna de texto |
| UUID | **GUID** (gerado automaticamente) |
| created_at | **Created On** (automático) |
| updated_at | **Modified On** (automático) |
| auth.uid() | **Created By / Modified By** (automático) |

### 2.2 Criar as Tabelas

Acesse **make.powerapps.com** → Ambiente `NID-COBEN-Dev` → **Tabelas** → **+ Nova tabela**

#### Tabela 1: `nid_Sprint`

| Coluna | Tipo | Obrigatório | Notas |
|--------|------|-------------|-------|
| Nome | Texto (primary) | Sim | Ex: "Sprint 1 — Jun/2026" |
| Numero | Inteiro | Sim | 1, 2, 3... |
| Data Inicio | Data | Sim | |
| Data Fim | Data | Sim | |
| Status | Choice | Sim | Valores: Planejada, Em Andamento, Finalizada |
| Objetivo | Texto multilinha | Não | |
| Risco | Choice | Não | Baixo, Médio, Alto, Crítico |

**Como criar no portal:**
1. Clique **+ Nova tabela** → Tipo: **Padrão**
2. Nome: `Sprint` (prefixo `nid_` é adicionado automaticamente)
3. Descrição: "Sprints do NID/COBEN"
4. Clique **Salvar**
5. Na tabela criada, clique **+ Nova coluna** para cada coluna acima
6. Para colunas **Choice**: clique **+ Nova coluna** → Tipo: **Choice** → **+ Nova choice** → adicione as opções

#### Tabela 2: `nid_Entrega`

| Coluna | Tipo | Obrigatório | Notas |
|--------|------|-------------|-------|
| Nome | Texto (primary) | Sim | Título da entrega |
| Sprint | Lookup → Sprint | Sim | Relacionamento N:1 |
| Status | Choice | Sim | a_fazer, em_andamento, revisao, concluido, despriorizado, cancelado |
| Prioridade | Choice | Não | Baixa, Normal, Alta, Urgente, Crítica |
| Fase | Choice | Não | Ideação, Business Case, Planejamento, Execução, Homologação, Implantação, Encerramento |
| Descricao | Texto multilinha | Não | |
| Data Inicio | Data | Não | |
| Data Fim | Data | Não | |
| Progresso | Inteiro | Não | 0 a 100 |
| Story Points | Inteiro | Não | |

**Para criar o Lookup (relacionamento):**
1. Na tabela `Entrega`, clique **+ Nova coluna**
2. Nome: `Sprint`
3. Tipo: **Lookup**
4. Tabela relacionada: `Sprint`
5. Salvar

#### Tabela 3: `nid_Tarefa`

| Coluna | Tipo | Obrigatório | Notas |
|--------|------|-------------|-------|
| Nome | Texto (primary) | Sim | Título |
| Entrega | Lookup → Entrega | Não | |
| Sprint | Lookup → Sprint | Sim | |
| Status | Choice | Sim | a_fazer, em_andamento, revisao, concluido, despriorizado, cancelado |
| Prioridade | Choice | Não | Baixa, Normal, Alta, Urgente, Crítica |
| Fase | Choice | Não | (mesmas 7 fases) |
| Descricao | Texto multilinha | Não | |
| Data Inicio | Data | Não | |
| Data Fim | Data | Não | |
| Story Points | Inteiro | Não | |
| Progresso | Inteiro | Não | 0-100 |
| Executor | Lookup → User | Não | |
| Revisor | Lookup → User | Não | |

#### Tabela 4: `nid_ChecklistItem`

| Coluna | Tipo | Obrigatório |
|--------|------|-------------|
| Nome | Texto (primary) | Sim |
| Tarefa | Lookup → Tarefa | Sim |
| Concluido | Sim/Não | Sim (default: Não) |
| Ordem | Inteiro | Não |

#### Tabela 5: `nid_Tag`

| Coluna | Tipo | Obrigatório |
|--------|------|-------------|
| Nome | Texto (primary) | Sim |
| Cor | Texto | Sim |

> Para vincular Tags às Tarefas, crie um **relacionamento N:N** entre `Tarefa` e `Tag`.

**Como criar N:N:**
1. Na tabela `Tarefa`, vá em **Relacionamentos**
2. **+ Novo relacionamento** → **Muitos para muitos**
3. Tabela relacionada: `Tag`
4. Salvar (cria automaticamente uma tabela intermediária)

#### Tabela 6: `nid_Comentario`

| Coluna | Tipo | Obrigatório |
|--------|------|-------------|
| Nome | Texto (primary, auto) | Sim |
| Tarefa | Lookup → Tarefa | Não |
| Evento | Lookup → Evento | Não |
| Texto | Texto multilinha | Sim |
| Evento Data | Data | Não |

#### Tabela 7: `nid_Anexo`

| Coluna | Tipo | Obrigatório |
|--------|------|-------------|
| Nome | Texto (primary) | Sim |
| Tarefa | Lookup → Tarefa | Não |
| Evento | Lookup → Evento | Não |
| Arquivo | Arquivo (File) | Sim |
| Tipo | Texto | Não |
| Tamanho | Inteiro | Não |
| Evento Data | Data | Não |

> O Dataverse suporta colunas tipo **File** e **Image** nativamente (até 128MB por arquivo).

#### Tabela 8: `nid_EventoCalendario`

| Coluna | Tipo | Obrigatório |
|--------|------|-------------|
| Nome | Texto (primary) | Sim |
| Data | Data | Sim |
| Hora Inicio | Texto | Não |
| Hora Fim | Texto | Não |
| Recorrencia | Choice | Não | unica, semanal, mensal |
| Descricao | Texto multilinha | Não |
| Local | Texto | Não |
| Cor | Texto | Não |

#### Tabela 9: `nid_MembroEvento`

| Coluna | Tipo | Obrigatório |
|--------|------|-------------|
| Nome | Texto (primary, auto) | Sim |
| Evento | Lookup → EventoCalendario | Sim |
| Usuario | Lookup → User | Sim |

#### Tabela 10: `nid_SprintReview`

| Coluna | Tipo | Obrigatório |
|--------|------|-------------|
| Nome | Texto (primary) | Sim |
| Sprint | Lookup → Sprint | Sim |
| Data | Data | Sim |
| NPS | Decimal | Não |
| Velocidade | Inteiro | Não |
| Percentual Entregue | Decimal | Não |
| Riscos | Texto multilinha | Não |
| Proximas Acoes | Texto multilinha | Não |

#### Tabela 11: `nid_ReviewItem`

| Coluna | Tipo | Obrigatório |
|--------|------|-------------|
| Nome | Texto (primary) | Sim |
| Review | Lookup → SprintReview | Sim |
| Entrega | Lookup → Entrega | Não |
| Disposicao | Choice | Sim | Concluído, Remanejado, Fora |
| Observacao | Texto multilinha | Não |

#### Tabela 12: `nid_PlanoAcaoItem`

| Coluna | Tipo | Obrigatório |
|--------|------|-------------|
| Nome | Texto (primary) | Sim |
| Subacao ID | Inteiro | Sim |
| Acao ID | Inteiro | Sim |
| OM ID | Inteiro | Sim |
| Sprint | Lookup → Sprint | Não |
| Status | Choice | Sim | nao_iniciado, em_andamento, concluido, atrasado |
| Prazo | Data | Não |
| Responsavel | Lookup → User | Não |
| Observacao | Texto multilinha | Não |

#### Tabela 13: `nid_OMStatus`

| Coluna | Tipo | Obrigatório |
|--------|------|-------------|
| Nome | Texto (primary) | Sim |
| OM ID | Inteiro | Sim |
| Descontinuado | Sim/Não | Sim |
| Justificativa | Texto multilinha | Não |
| Descontinuado Por | Lookup → User | Não |
| Descontinuado Em | Data/Hora | Não |

#### Tabela 14: `nid_Risco`

| Coluna | Tipo | Obrigatório |
|--------|------|-------------|
| Nome | Texto (primary) | Sim |
| Codigo | Texto | Sim |
| Descricao | Texto multilinha | Não |
| Categoria | Choice | Sim | estrategico, operacional, financeiro, conformidade, tecnologico, reputacional |
| Abordagem | Choice | Sim | mitigar, aceitar, transferir, evitar |
| Nivel | Choice | Sim | baixo, medio, alto, critico |
| Status | Choice | Sim | identificado, em_tratamento, monitorado, materializado, encerrado |
| Responsavel | Lookup → User | Não |
| Data Identificacao | Data | Não |
| Prazo Revisao | Data | Não |
| Probabilidade | Inteiro | Não | 1-5 |
| Impacto | Inteiro | Não | 1-5 |

#### Tabela 15: `nid_RiscoControle`

| Coluna | Tipo | Obrigatório |
|--------|------|-------------|
| Nome | Texto (primary) | Sim |
| Risco | Lookup → Risco | Sim |
| Tipo | Choice | Sim | preventivo, detectivo, corretivo |
| Eficacia | Choice | Não | alta, media, baixa |

> No Dataverse, em vez de JSONB para controles, usamos uma **tabela filho** com lookup. Mais limpo e consultável.

#### Tabela 16: `nid_Ideia`

| Coluna | Tipo | Obrigatório |
|--------|------|-------------|
| Nome | Texto (primary) | Sim |
| Tipo | Choice | Sim | projeto, curso, workshop, ferramenta, processo |
| Descricao | Texto multilinha | Não |
| Status | Choice | Sim | rascunho, em_avaliacao, aprovada, em_andamento, concluida, descartada |
| Autor | Lookup → User | Não |
| Prioridade | Choice | Não | baixa, media, alta |

#### Tabela 17: `nid_AuditLog`

| Coluna | Tipo | Obrigatório |
|--------|------|-------------|
| Nome | Texto (primary, auto) | Sim |
| Acao | Texto | Sim |
| Tipo Entidade | Texto | Não |
| Entidade ID | Texto | Não |
| Resumo | Texto multilinha | Não |
| Usuario | Lookup → User | Não |

#### Tabela 18: `nid_ReminderLog`

| Coluna | Tipo | Obrigatório |
|--------|------|-------------|
| Nome | Texto (primary, auto) | Sim |
| Tipo | Choice | Sim | teams, email |
| Destinatario | Texto | Não |
| Conteudo | Texto multilinha | Não |
| Status | Choice | Sim | enviado, erro |
| Erro | Texto | Não |

### 2.3 Inserir Dados Iniciais

#### Riscos COBEN (6 registros):

Na tabela `nid_Risco`, clique **+ Nova linha** e insira:

1. RSK-001 | Erro no cálculo de benefícios | operacional | mitigar | alto | em_tratamento
2. RSK-002 | Falha na integração de sistemas | tecnologico | mitigar | alto | em_tratamento
3. RSK-003 | Não conformidade regulatória | conformidade | evitar | critico | em_tratamento
4. RSK-004 | Perda de dados sensíveis | tecnologico | mitigar | critico | identificado
5. RSK-005 | Atraso na implantação de projetos | operacional | mitigar | medio | monitorado
6. RSK-006 | Rotatividade da equipe técnica | operacional | aceitar | medio | monitorado

---

## FASE 3 — Power Apps Canvas App (Dia 4-10)

### 3.1 Criar o App

1. Acesse **make.powerapps.com**
2. **+ Criar** → **App em branco** → **Canvas App**
3. Nome: `NID Agile Board`
4. Formato: **Tablet** (layout mais parecido com o app atual)
5. Clique **Criar**

### 3.2 Estrutura de Telas

Crie as seguintes telas (no editor, **+ Nova tela**):

```
📱 Telas do App
├── scrLogin          ← Tela de login (se necessário, o Entra ID já autentica)
├── scrDashboard      ← Dashboard com métricas
├── scrKanban         ← Kanban board
├── scrBacklog        ← Backlog por fase
├── scrCalendario     ← Calendário mensal
├── scrEquipe         ← Cards da equipe
├── scrReviews        ← Reviews de sprint
├── scrPlanoAcao      ← Plano de Ação COBEN
├── scrRiscos         ← Riscos Organizacionais
├── scrIdeias         ← Ideias & Aprendizado
├── scrLembretes      ← Configuração de lembretes
├── scrAdmin          ← Painel de administração
├── scrDetalhe        ← Modal de tarefa (detalhes/equipe/tags/checklist)
└── scrReporte        ← Reporte de Conformidade
```

### 3.3 Sidebar de Navegação

1. Insira um **Container vertical** na esquerda (largura 250px)
2. Cor de fundo: `ColorValue("#1a1a2e")` (tema escuro) ou `White` (claro)
3. Adicione botões de navegação:

```
// Botão de navegação (exemplo para Dashboard)
OnSelect: Navigate(scrDashboard, ScreenTransition.Fade)
Text: "Dashboard"
Icon: Icon.BarChart
Fill: If(App.ActiveScreen = scrDashboard, ColorValue("#2B6AFF"), Transparent)
Color: If(App.ActiveScreen = scrDashboard, White, ColorValue("#94a3b8"))
```

4. **Logo FUNCEF**: Insira um controle **Image** no topo da sidebar
   - Image: `"data:image/png;base64,..."` (use o mesmo base64 do app atual)

5. **Seletor de Sprint**: Insira um **Dropdown** abaixo do logo
```
Items: Sort(nid_Sprints, Numero, SortOrder.Ascending)
OnChange: Set(varSprintAtual, Self.Selected)
```

### 3.4 Tela Dashboard

1. **Métricas em cards**: Use um **Container horizontal** com 4 cards

```
// Card de métricas — Total de Tarefas
Text: CountRows(Filter(nid_Tarefas, Sprint.Numero = varSprintAtual.Numero))

// Card — Concluídas
Text: CountRows(Filter(nid_Tarefas, Sprint.Numero = varSprintAtual.Numero, Status.Value = "concluido"))

// Card — % Progresso
Text: Text(
    RoundUp(
        CountRows(Filter(nid_Tarefas, Sprint.Numero = varSprintAtual.Numero, Status.Value = "concluido")) /
        Max(CountRows(Filter(nid_Tarefas, Sprint.Numero = varSprintAtual.Numero)), 1) * 100,
    0) & "%"
)

// Card — Story Points
Text: Sum(Filter(nid_Tarefas, Sprint.Numero = varSprintAtual.Numero), StoryPoints)
```

2. **Gráfico de progresso**: Insira **Chart** (gráfico de barras ou pizza)
```
Items: GroupBy(
    Filter(nid_Tarefas, Sprint.Numero = varSprintAtual.Numero),
    "Status",
    "Contagem"
)
```

### 3.5 Tela Kanban

1. Crie 4 **Containers verticais** lado a lado (colunas):
   - A Fazer | Em Andamento | Revisão | Concluído

2. Dentro de cada coluna, insira uma **Gallery vertical**:

```
// Gallery "A Fazer"
Items: Sort(
    Filter(nid_Tarefas,
        Sprint.Numero = varSprintAtual.Numero,
        Status.Value = "a_fazer"
    ),
    Prioridade.Value, SortOrder.Descending
)

// Template do card na Gallery:
// - Retângulo colorido no topo (barra de prioridade)
// - Label com título
// - Labels com datas, story points
// - Ícones de checklist
```

3. **Drag & drop**: O Power Apps Canvas não tem drag-and-drop nativo. Alternativas:
   - Use **botões** em cada card para mover entre colunas:
     ```
     // Botão "Mover para Em Andamento"
     OnSelect: Patch(nid_Tarefas, ThisItem, {Status: {Value: "em_andamento"}})
     ```
   - Ou use **Power Apps Component Framework (PCF)** para criar um componente Kanban customizado com drag-and-drop

### 3.6 Tela Backlog (por fase)

```
// Gallery agrupada por fase
Items: Sort(
    Filter(nid_Tarefas, Sprint.Numero = varSprintAtual.Numero),
    Fase.Value
)

// Cabeçalhos de seção
GroupBy(
    Filter(nid_Tarefas, Sprint.Numero = varSprintAtual.Numero),
    "Fase",
    "Tarefas"
)
```

### 3.7 Tela Calendário

Use o componente **Calendar** do Power Apps:

1. Vá em **Inserir** → **Obter mais componentes** → Busque "Calendar"
2. Ou crie manualmente com uma Gallery de 7 colunas × 6 linhas
3. Para eventos recorrentes:

```
// Gerar ocorrências do Weekly (toda quinta)
ForAll(
    Sequence(52, 0) As idx,
    {
        Data: DateAdd(Date(2026, 1, 1), idx.Value * 7 + (5 - Weekday(Date(2026,1,1))), TimeUnit.Days),
        Titulo: "Weekly do Núcleo de Dados",
        Hora: "15:00"
    }
)
```

### 3.8 Modal de Tarefa (Detalhes)

1. Crie um **Container** que cubra toda a tela (overlay)
2. Visibilidade: `varMostrarModal`
3. Dentro, crie as 5 abas com um **TabList** ou botões:

```
// Abas do modal
Set(varAbaModal, "detalhes") // default

// Conteúdo condicional
If(varAbaModal = "detalhes",
    // Campos de detalhe...
    ,
    varAbaModal = "equipe",
    // Dropdowns de executor/revisor...
    ,
    varAbaModal = "tags",
    // Gallery de tags...
    ,
    varAbaModal = "checklist",
    // Gallery com checkboxes...
    ,
    // Cronograma...
)
```

4. **Salvar alterações:**
```
// Botão Salvar
OnSelect:
    Patch(nid_Tarefas, varTarefaAtual, {
        'Nome': txtTitulo.Text,
        'Descricao': txtDescricao.Text,
        'Status': drpStatus.Selected,
        'Prioridade': drpPrioridade.Selected,
        'Data Fim': dtpDataFim.SelectedDate
    });
    Set(varMostrarModal, false);
    Notify("Tarefa salva com sucesso!", NotificationType.Success)
```

### 3.9 Tema Claro/Escuro

```
// Variável global no App.OnStart
Set(varTemaEscuro, false);

// Toggle na sidebar
OnCheck: Set(varTemaEscuro, !varTemaEscuro)

// Usar em todas as telas:
Fill: If(varTemaEscuro, ColorValue("#0f172a"), White)
Color: If(varTemaEscuro, White, ColorValue("#1e293b"))
```

### 3.10 Paleta FUNCEF

```
// Definir no App.OnStart
Set(varCores, {
    AzulFUNCEF: ColorValue("#2B6AFF"),
    LaranjaFUNCEF: ColorValue("#FF7B39"),
    Sucesso: ColorValue("#22D172"),
    Atencao: ColorValue("#F5A524"),
    Critico: ColorValue("#FF4757"),
    FundoClaro: White,
    FundoEscuro: ColorValue("#0f172a"),
    TextoClaro: ColorValue("#1e293b"),
    TextoEscuro: White
})
```

---

## FASE 4 — Power Automate (Dia 11-13)

### 4.1 Fluxo: Lembrete Diário (Seg-Sex 8h)

1. Acesse **make.powerautomate.com**
2. **+ Criar** → **Fluxo de nuvem agendado**
3. Nome: `NID - Lembrete Diário`
4. Recorrência: A cada 1 dia, às 08:00, apenas Seg-Sex

**Passos do fluxo:**

```
Gatilho: Recorrência
  ├── Horário: 08:00 BRT
  └── Dias: Segunda, Terça, Quarta, Quinta, Sexta
         │
         ▼
Ação: Listar linhas (Dataverse)
  ├── Tabela: nid_Tarefas
  └── Filtro: statuscode ne 'concluido' and nid_datafim lt '@{utcNow()}'
         │
         ▼
Condição: length(outputs('Listar_linhas')?['body/value']) > 0
  ├── Sim ─▶ Ação: Postar mensagem no Teams
  │         ├── Canal: NID/COBEN
  │         └── Corpo: Adaptive Card (ver modelo abaixo)
  │              │
  │              ▼
  │         Ação: Enviar e-mail (Outlook)
  │         ├── Para: equipe-nid@funcef.com.br
  │         └── Assunto: 🔔 Lembrete NID — @{length(...)} tarefas atrasadas
  │
  └── Não ─▶ (nada)
```

**Adaptive Card para o Teams:**
```json
{
    "type": "AdaptiveCard",
    "version": "1.4",
    "body": [
        {
            "type": "ColumnSet",
            "columns": [
                {
                    "type": "Column",
                    "width": "auto",
                    "items": [{"type": "Image", "url": "URL_LOGO_FUNCEF", "size": "Small"}]
                },
                {
                    "type": "Column",
                    "width": "stretch",
                    "items": [
                        {"type": "TextBlock", "text": "🔔 Lembrete NID/COBEN", "size": "Large", "weight": "Bolder", "color": "Accent"},
                        {"type": "TextBlock", "text": "@{formatDateTime(utcNow(), 'dddd, dd MMMM yyyy', 'pt-BR')}", "isSubtle": true}
                    ]
                }
            ]
        },
        {
            "type": "TextBlock",
            "text": "🚨 TAREFAS ATRASADAS: @{length(body('Listar_linhas')?['value'])}",
            "weight": "Bolder",
            "color": "Attention"
        }
    ],
    "actions": [
        {"type": "Action.OpenUrl", "title": "Abrir Board", "url": "LINK_DO_APP"}
    ]
}
```

### 4.2 Fluxo: Notificação de Prazo Próximo

```
Gatilho: Recorrência (diária, 08:30)
  │
  ▼
Ação: Listar linhas (Dataverse)
  └── Filtro: nid_datafim ge '@{utcNow()}' and nid_datafim le '@{addDays(utcNow(), 3)}'
  │
  ▼
Para cada tarefa:
  └── Ação: Postar mensagem no Teams (menção ao responsável)
```

### 4.3 Fluxo: Lembrete de Reunião do Dia

```
Gatilho: Recorrência (diária, 07:00)
  │
  ▼
Ação: Listar linhas — nid_EventoCalendario
  └── Filtro: reuniões de hoje (considerar recorrência)
  │
  ▼
Condição: há reuniões?
  └── Sim: Postar no Teams + E-mail
```

### 4.4 Fluxo: Auditoria Automática

```
Gatilho: Quando uma linha é adicionada, modificada ou excluída (Dataverse)
  ├── Tabela: nid_Tarefas (repita para outras tabelas)
  │
  ▼
Ação: Adicionar nova linha
  ├── Tabela: nid_AuditLog
  ├── Acao: "tarefa_modificada"
  └── Resumo: "Tarefa '@{triggerOutputs()?['body/nid_nome']}' foi @{triggerOutputs()?['body/_action']}"
```

### 4.5 Fluxo: Resumo Semanal (Sexta 16h)

```
Gatilho: Recorrência (Sexta, 16:00)
  │
  ▼
Paralelo:
  ├── Listar tarefas concluídas esta semana
  ├── Listar entregas atualizadas
  ├── Listar eventos da semana
  └── Listar riscos em tratamento
  │
  ▼
Ação: Compor resumo HTML
  │
  ▼
Paralelo:
  ├── Postar no Teams (Adaptive Card rico)
  └── Enviar e-mail (Outlook) com HTML formatado
```

---

## FASE 5 — Power BI (Dia 14-16)

### 5.1 Conectar ao Dataverse

1. Abra **Power BI Desktop** (download: powerbi.microsoft.com)
2. **Obter Dados** → **Dataverse**
3. Selecione o ambiente `NID-COBEN-Producao`
4. Importe as tabelas: Sprint, Entrega, Tarefa, Risco, PlanoAcaoItem

### 5.2 Dashboards a Criar

#### Dashboard 1: Visão Geral do Sprint

| Visual | Dados | Tipo |
|--------|-------|------|
| Card | Total de tarefas | KPI |
| Card | % Concluído | KPI |
| Card | Story Points entregues | KPI |
| Gráfico de barras | Tarefas por status | Bar chart |
| Gráfico de pizza | Tarefas por fase | Pie chart |
| Gráfico de linha | Burndown (tarefas restantes por dia) | Line chart |
| Tabela | Top 10 tarefas atrasadas | Table |

**Medida DAX — % Conclusão:**
```dax
% Conclusão =
DIVIDE(
    COUNTROWS(FILTER(nid_Tarefas, nid_Tarefas[Status] = "concluido")),
    COUNTROWS(nid_Tarefas),
    0
)
```

**Medida DAX — Story Points Entregues:**
```dax
SP Entregues =
CALCULATE(
    SUM(nid_Tarefas[StoryPoints]),
    nid_Tarefas[Status] = "concluido"
)
```

#### Dashboard 2: Riscos e Conformidade

| Visual | Dados |
|--------|-------|
| Mapa de calor | Riscos por probabilidade × impacto |
| Barras empilhadas | Riscos por abordagem e nível |
| KPI | Riscos críticos/altos em tratamento |
| Tabela | Controles e sua eficácia |
| Gauge | % do Plano de Ação concluído |

#### Dashboard 3: Equipe e Produtividade

| Visual | Dados |
|--------|-------|
| Barras | Tarefas por membro |
| Barras | Story points por membro |
| Linha | Velocidade por sprint |
| Tabela | NPS das reviews |

### 5.3 Publicar e Compartilhar

1. No Power BI Desktop: **Publicar** → Workspace `NID-COBEN`
2. No Power BI Service (app.powerbi.com):
   - Configure **atualização agendada** (a cada 1h ou em tempo real com DirectQuery)
   - **Compartilhe** com o grupo `NID-Integrantes`
3. **Embed no Teams**: No Teams → **+** Aba → **Power BI** → selecione o dashboard

---

## FASE 6 — Copilot Studio + Azure OpenAI (Dia 17-19)

Para substituir as chamadas à API Claude (Giro da Semana, Reporte de Conformidade):

### 6.1 Opção A — Copilot Studio (Mais simples)

1. Acesse **copilotstudio.microsoft.com**
2. **+ Criar** → **Copilot**
3. Nome: `NID Copilot`
4. Crie **Tópicos** para cada funcionalidade:

**Tópico: Giro da Semana**
```
Gatilho: "gerar giro da semana", "NID NEWS"
Ação: Power Automate (buscar dados da semana no Dataverse)
Mensagem: Prompt com persona de jornalista + dados
Resposta: Geração com GPT-4 (integrado ao Copilot)
```

**Tópico: Reporte de Conformidade**
```
Gatilho: "gerar reporte", "relatório de conformidade"
Ação: Power Automate (buscar riscos + PA + auditoria)
Mensagem: Prompt de analista de compliance + dados
Resposta: Relatório formatado
```

### 6.2 Opção B — Azure OpenAI (Mais controle)

1. No **portal.azure.com** → Criar recurso **Azure OpenAI**
2. Deploy do modelo `gpt-4o` ou `gpt-4o-mini`
3. No Power Automate, use o conector **HTTP** para chamar:

```
POST https://SEU-RECURSO.openai.azure.com/openai/deployments/gpt-4o/chat/completions?api-version=2024-02-01
Headers:
  api-key: SUA_CHAVE
  Content-Type: application/json
Body:
{
  "messages": [
    {"role": "system", "content": "Você é um jornalista do NID/COBEN..."},
    {"role": "user", "content": "@{variables('dadosDaSemana')}"}
  ],
  "max_tokens": 4000
}
```

4. No Power Apps, chame o fluxo do Power Automate:
```
// Botão "Gerar NID NEWS"
OnSelect:
    Set(varGiroTexto,
        NIDGiroSemana.Run(varSprintAtual.Numero).resultado
    )
```

---

## FASE 7 — Integração com Teams (Dia 20-21)

### 7.1 Publicar o Power App como Tab no Teams

1. No Power Apps, clique **Publicar**
2. Vá em **Teams** → Canal do NID
3. **+** → **Power Apps** → Selecione `NID Agile Board`
4. Pronto — o app abre direto dentro do Teams

### 7.2 Bot de Notificações

Com o Copilot Studio, o bot pode:
- Responder perguntas: "Quantas tarefas estão atrasadas?"
- Aceitar comandos: "Marcar tarefa X como concluída"
- Enviar proativamente: Resumos diários no canal

### 7.3 Tabs Adicionais no Teams

| Tab | Conteúdo |
|-----|----------|
| Board | Power App (NID Agile Board) |
| Dashboards | Power BI (embed) |
| Documentos | SharePoint (atas, anexos) |
| Wiki | Documentação do NID |

---

## FASE 8 — SharePoint para Documentos (Dia 22)

### 8.1 Criar Site SharePoint

1. Acesse **sharepoint.com** → **+ Criar site** → **Site de equipe**
2. Nome: `NID COBEN`
3. Crie as bibliotecas:
   - `Atas de Reunião`
   - `Anexos de Tarefas`
   - `Documentos de Sprint`
   - `Plano de Ação`

### 8.2 Integrar com Power Apps

No Power Apps, use o conector **SharePoint**:

```
// Upload de arquivo
OnSelect:
    Patch(
        'Anexos de Tarefas',
        Defaults('Anexos de Tarefas'),
        {
            Title: txtNomeArquivo.Text,
            {File: uplArquivo.Content}
        }
    )

// Listar arquivos
Items: Filter(
    'Anexos de Tarefas',
    TarefaID = varTarefaAtual.ID
)
```

---

## FASE 9 — Segurança e Governança (Dia 23)

### 9.1 Roles no Dataverse

1. Vá em **admin.powerplatform.microsoft.com** → Ambientes → `NID-COBEN` → **Security roles**
2. Crie roles:

| Role | Permissões |
|------|-----------|
| NID Admin | CRUD em todas as tabelas + gerenciar usuários |
| NID Integrante | CRUD em tarefas, comentários, anexos. Read em sprints. |
| NID Gestor | CRUD em sprints, reviews, riscos. Read em tudo. |
| NID Visitante | Read-only em tudo |

3. Atribua os roles via **Teams de segurança do Dataverse**

### 9.2 Auditoria Nativa

O Dataverse já tem auditoria nativa:
1. No ambiente → **Configurações** → **Auditoria**
2. Habilite a auditoria nas tabelas desejadas
3. Logs acessíveis via **admin.powerplatform.microsoft.com** → Auditoria

---

## FASE 10 — Testes e Deploy (Dia 24-25)

### 10.1 Testar

1. No Power Apps: **Testar o app** (F5 no editor)
2. Verifique cada tela e fluxo
3. Teste com diferentes roles (admin, integrante, visitante)
4. Valide os fluxos do Power Automate: **Testar** → **Manualmente**

### 10.2 Migrar Dados do Supabase

1. No Supabase Dashboard: **SQL Editor** → `SELECT * FROM tabela` → Export CSV
2. No Dataverse: **Importar dados** → Upload CSV → Mapear colunas
3. Ordem de importação:
   1. Sprints (sem dependências)
   2. Tags
   3. Entregas (depende de Sprint)
   4. Tarefas (depende de Sprint + Entrega)
   5. Checklist, Comentários, Anexos (dependem de Tarefa)
   6. Eventos, Riscos, PlanoAcao, Ideias
   7. Logs

### 10.3 Publicar em Produção

1. **Solução**: No Power Apps → **Soluções** → Empacote tudo (app, tabelas, fluxos) em uma solução
2. **Exportar** a solução como arquivo `.zip`
3. **Importar** no ambiente de Produção
4. Publicar o app no Teams para toda a equipe

---

## Cronograma Resumido

| Fase | Atividade | Dias | Acumulado |
|------|----------|------|-----------|
| 1 | Ambiente + Licenças | 1 | 1 |
| 2 | Dataverse (18 tabelas) | 2 | 3 |
| 3 | Power Apps (14 telas) | 7 | 10 |
| 4 | Power Automate (5 fluxos) | 3 | 13 |
| 5 | Power BI (3 dashboards) | 3 | 16 |
| 6 | Copilot Studio / Azure OpenAI | 3 | 19 |
| 7 | Integração Teams | 2 | 21 |
| 8 | SharePoint | 1 | 22 |
| 9 | Segurança | 1 | 23 |
| 10 | Testes + Deploy | 2 | 25 |
| **Total** | | **~25 dias úteis** | **~5 semanas** |

---

## Comparativo Final

| Aspecto | App Atual (Supabase) | Power Platform |
|---------|---------------------|----------------|
| **Custo** | ~$25/mês (Supabase Pro) | ~R$100-500/mês (licenças) |
| **Performance** | Rápido (HTML nativo) | Bom (pode ser mais lento no canvas) |
| **Manutenção** | Precisa de dev (HTML/JS) | Low-code (mais acessível) |
| **Integração MS** | Via webhooks | Nativa (Teams, Outlook, SharePoint) |
| **IA** | Claude API (excelente) | Azure OpenAI/Copilot (bom) |
| **Offline** | Não | Power Apps offline mode |
| **Mobile** | Responsivo | App nativo (iOS/Android) |
| **Governança** | RLS básico | Enterprise-grade (Entra ID, DLP) |
| **Auditoria** | Custom (audit_log) | Nativa + custom |
| **Backup** | Manual | Automático (Dataverse) |
| **Escalabilidade** | Limitada ao plano | Ilimitada (Dataverse) |

---

## Dicas Importantes

1. **Comece pelo Dataverse** — o modelo de dados é a base de tudo
2. **Use Soluções** — empacote tudo em uma solução gerenciável desde o início
3. **Power Apps Model-Driven** vs **Canvas**:
   - **Canvas** = mais controle visual (mais parecido com seu app atual)
   - **Model-Driven** = mais rápido de construir, menos customizável
   - Recomendo **Canvas** para manter a identidade visual FUNCEF
4. **Power Automate Premium** é necessário para o conector do Dataverse
5. **Environment Variables** = use para configurações (webhook URLs, etc.)
6. **ALM (Application Lifecycle Management)** = use soluções para promover Dev → Produção
7. **O catálogo PA_GB** (62 subações) pode ser importado via CSV no Dataverse
8. **Power Fx** é a linguagem de fórmulas do Power Apps — parecida com Excel, não com JavaScript

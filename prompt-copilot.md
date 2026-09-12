# NID/COBEN Agile Board — Descrição do Projeto & Prompt para Copilot

## Visão Geral do Projeto

O **NID/COBEN Agile Board** é uma aplicação web completa de gestão ágil desenvolvida para o **Núcleo de Inovação e Dados (NID)** da **COBEN/FUNCEF** (Coordenação de Gestão de Benefícios da Fundação dos Economiários Federais).

A aplicação é um **arquivo único (`index.html`)** com aproximadamente 600KB contendo todo o HTML, CSS e JavaScript inline, incluindo o logo FUNCEF em base64. O backend utiliza **Supabase** (PostgreSQL + Auth + Storage + RLS).

---

## Stack Tecnológica

| Camada | Tecnologia |
|--------|-----------|
| Frontend | HTML5 + CSS3 + JavaScript vanilla (arquivo único) |
| Backend/DB | Supabase (PostgreSQL com Row Level Security) |
| Autenticação | Supabase Auth (email + senha) |
| Armazenamento | Supabase Storage (bucket `task-files`) |
| IA | API Claude da Anthropic (chamada direta do browser) |
| Deploy | Netlify (SPA com redirect) |
| Integrações | Microsoft Teams (webhooks/Adaptive Cards), Resend (e-mail) |

---

## Funcionalidades Implementadas

### 1. Autenticação e Usuários
- Login com e-mail e senha via Supabase Auth
- Cadastro de novos usuários direto da tela de login
- Perfis ricos: nome, iniciais, cor, área, cargo, foto, bio, senioridade, habilidades (JSONB), projetos liderados
- Tipos de usuário: admin, integrante, gestor, coordenador, visitante
- Admin pode excluir usuários (RPC `delete_user_admin` com security definer)
- Fotos de perfil via Supabase Storage (prefixo `avatars/`)

### 2. Gestão de Sprints
- Sidebar com sprints 2026–2027
- Indicador de risco e % de conclusão por sprint
- Sprint 1 finalizada (dados protegidos)
- Sprint 2 planejada (dados protegidos)
- Sprints 3+ editáveis

### 3. Visões (6 + extras)
- **Dashboard**: Métricas consolidadas, gráficos de progresso
- **Kanban**: Cards estilo ClickUp com drag-and-drop
- **Backlog**: Agrupado por fase do ciclo (Ideação → Business Case → Planejamento → Execução → Homologação → Implantação → Encerramento)
- **Calendário**: Mensal com eventos, subtarefas e entregas planejadas, eventos recorrentes (Weekly do Núcleo), anexos e comentários por ocorrência
- **Equipe**: Cards de membros com foto, skills, projetos
- **Reviews**: NPS, velocidade, % entregue, entregas com disposição (concluído/remanejado/fora), riscos, próximas ações, múltiplas reviews por sprint

### 4. Tarefas e Entregas
- Cards com barra de prioridade colorida, tags, avatares empilhados
- Contador de checklist, story points, progresso, datas
- Modal com 5 abas: Detalhes, Equipe, Tags, Checklist, Cronograma
- Status: a_fazer, em_andamento, revisao, concluido, despriorizado, cancelado
- Comentários e anexos por tarefa
- Filtro por fase do ciclo

### 5. Plano de Ação COBEN — Gestão de Benefício
- Catálogo de 62 subações (PA_GB) embutido no código
- Tabela `pa_items` para estado e vínculo com sprints
- Agrupamento por Ação e Oportunidade de Melhoria (OM)
- Descontinuação de OM inteira com justificativa obrigatória
- Reativação de OMs descontinuadas
- Tabela `pa_om_status` para estado de descontinuação

### 6. Riscos Organizacionais
- CRUD completo com 6 riscos COBEN pré-cadastrados
- Campos: código, nome, descrição, categoria, abordagem (mitigar/aceitar/transferir/evitar), nível (baixo/médio/alto/crítico), status (identificado/em_tratamento/monitorado/materializado/encerrado), responsável, data identificação, prazo revisão
- Controles em JSONB: descrição, tipo (preventivo/detectivo/corretivo), eficácia
- Vinculação com tarefas de sprint
- Cards agrupados por abordagem, expansíveis

### 7. Giro da Semana (NID NEWS)
- Geração por IA com persona de jornalista do NID
- Layout estilo jornal com grid CSS (manchete, editorial, painel de dados, despachos, inovação, radar, perspectiva, frase da semana)
- Coleta automática de dados da semana: tarefas, entregas, checklist, eventos, comentários, auditoria, ideias, atividade por membro
- Compartilhamento via Teams (webhook + Adaptive Card)
- Cópia formatada para clipboard
- Impressão com layout otimizado

### 8. Reporte Semanal de Conformidade
- Relatório gerado por IA consolidando riscos, auditoria e plano de ação
- Métricas de status, vencimentos, ações em andamento
- Cópia para clipboard e Teams

### 9. Ideias & Aprendizado
- Tabela `ideias` para projetos embrionários, cursos, workshops
- CRUD com categorização

### 10. Lembretes & Automações
- Configuração de regras: tarefas atrasadas, prazos próximos, reuniões do dia, entregas, plano de ação
- Envio manual via Teams (webhook) e e-mail (Resend API)
- Preview antes de enviar
- Histórico de envios (`reminder_log`)
- Supabase Edge Function para automação (pg_cron + pg_net)
- Configuração persistida em localStorage

### 11. Governança (Admin)
- Auditoria (`audit_log`) de ações do sistema
- Gestão de usuários e permissões
- Importação de dados do Plano de Ação
- Painel de governança

### 12. Interface
- Tema claro/escuro com toggle persistido
- Identidade visual FUNCEF (azul #2B6AFF, laranja #FF7B39)
- Logo FUNCEF com fundo transparente e brilho azul
- Responsivo
- Paleta: Sucesso #22D172, Atenção #F5A524, Crítico #FF4757

---

## Estrutura do Banco de Dados (Supabase)

### Tabelas principais:
| Tabela | Descrição |
|--------|-----------|
| `profiles` | Perfis de usuário (nome, iniciais, cor, área, cargo, tipo, foto_url, bio, senioridade, habilidades, projetos_liderados) |
| `sprints` | Sprints com datas, status |
| `sprint_entregas` | Entregas por sprint (status inclui despriorizado/cancelado) |
| `subtarefas` | Tarefas/subtarefas com status, datas, story points, fase |
| `task_tags` | Tags das tarefas |
| `task_comments` | Comentários (suporta evento_id e evento_data para reuniões) |
| `task_attachments` | Anexos (suporta evento_id e evento_data) |
| `checklist_items` | Itens de checklist |
| `calendar_events` | Eventos do calendário (suporta recorrência semanal) |
| `event_members` | Membros dos eventos |
| `sprint_reviews` | Reviews de sprint (múltiplas por sprint) |
| `sprint_review_items` | Itens de review com disposição |
| `pa_items` | Plano de ação — estado das subações |
| `pa_om_status` | Estado de descontinuação das OMs |
| `riscos` | Riscos organizacionais com controles (JSONB) |
| `ideias` | Projetos embrionários e aprendizado |
| `reminder_log` | Log de lembretes enviados |
| `audit_log` | Log de auditoria |

### Segurança:
- RLS habilitado em todas as tabelas
- Leitura/escrita exige `auth.role() = 'authenticated'`
- Função RPC `delete_user_admin` com security definer para exclusão de usuários

---

## Arquivos do Projeto

```
.
├── index.html                              ← App completo (HTML + CSS + JS + logo base64)
├── logo.png                                ← Logo FUNCEF transparente
├── schema.sql                              ← Schema base (profiles + Auth + sprints + tarefas)
├── schema_addon.sql                        ← Comentários + anexos + checklist/tags em entregas
├── schema_addon_v7.sql                     ← Tipos de usuário + admin + auditoria
├── schema_addon_v8.sql                     ← Calendário com eventos custom
├── schema_addon_v9.sql                     ← Anexos e comentários em eventos
├── schema_addon_v10.sql                    ← Exclusão de usuário pelo admin
├── schema_addon_v11.sql                    ← Weekly quinta-feira 15h
├── schema_addon_v12.sql                    ← Anexos/comentários por ocorrência de recorrente
├── schema_addon_v13.sql                    ← Reviews completas com histórico
├── schema_addon_v14.sql                    ← Status despriorizado e cancelado
├── schema_addon_v15.sql                    ← Perfis ricos (foto, bio, skills)
├── schema_addon_v16.sql                    ← Plano de Ação COBEN
├── schema_addon_v17.sql                    ← Ideias & Aprendizado
├── schema_addon_v18.sql                    ← Descontinuação de OM
├── schema_addon_v19.sql                    ← Lembretes automáticos
├── schema_addon_v20.sql                    ← Riscos Organizacionais
├── supabase-edge-function-reminders.js     ← Edge Function para lembretes automáticos
├── netlify.toml                            ← SPA redirect para deploy
└── README.md                              ← Documentação
```

---

## Restrições Importantes

1. **Sprint 1** está finalizada — NÃO alterar seus registros
2. **Sprint 2** está planejada — NÃO alterar seus registros, apenas organizar visualmente
3. **Sprint 3+** podem ser reorganizadas
4. **Plano de Ação** considera APENAS a aba "Gestão de Benefício" (62 subações)
5. O app é para **uso interno** do Núcleo de Inovação e Dados da COBEN/FUNCEF
6. A **chave anon** do Supabase é pública por design (protegido por RLS)

---

---

# PROMPT PARA O COPILOT

Copie e cole o prompt abaixo no Microsoft Copilot (ou outro assistente de IA) para dar contexto completo do projeto:

---

```
Você é um assistente técnico especializado em desenvolvimento web e gestão de projetos ágeis. Estou trabalhando em um projeto chamado **NID/COBEN Agile Board**, uma aplicação web de gestão ágil para o Núcleo de Inovação e Dados (NID) da COBEN/FUNCEF.

## Contexto do Projeto

O app é um **arquivo único HTML (~600KB)** com CSS e JavaScript inline. O backend usa **Supabase** (PostgreSQL + Auth + Storage com Row Level Security). O deploy é feito no **Netlify**. A identidade visual segue a paleta FUNCEF (azul #2B6AFF, laranja #FF7B39).

## O que já está construído:

1. **Autenticação** com Supabase Auth (email/senha), cadastro de usuários, perfis ricos (foto, bio, skills, cargo, área, senioridade), tipos de usuário (admin/integrante/gestor/coordenador/visitante)

2. **6 visões principais**: Dashboard (métricas), Kanban (drag-and-drop), Backlog (por fase do ciclo), Calendário (eventos recorrentes, anexos por ocorrência), Equipe (cards de membros), Reviews (NPS, velocidade, disposição de entregas)

3. **Gestão completa de tarefas**: cards estilo ClickUp com prioridade, tags, avatares, checklist, story points, progresso, datas, comentários, anexos. Status: a_fazer, em_andamento, revisao, concluido, despriorizado, cancelado

4. **Fases do ciclo**: Ideação → Business Case → Planejamento → Execução → Homologação → Implantação → Encerramento

5. **Plano de Ação COBEN** (Gestão de Benefício): 62 subações catalogadas, agrupadas por Ação e OM (Oportunidade de Melhoria), com descontinuação de OMs e vínculo com sprints

6. **Riscos Organizacionais**: CRUD com 6 riscos COBEN pré-cadastrados, controles em JSONB (preventivo/detectivo/corretivo), vinculação com tarefas, agrupamento por abordagem (mitigar/aceitar/transferir/evitar)

7. **Giro da Semana (NID NEWS)**: Geração por IA com persona jornalística, layout estilo jornal com grid CSS, compartilhamento via Teams (Adaptive Cards), impressão

8. **Reporte de Conformidade**: Relatório IA consolidando riscos + auditoria + plano de ação para a gestão

9. **Lembretes automáticos**: Configuração de regras, envio via Teams (webhook) e e-mail (Resend), Edge Function Supabase para automação com pg_cron

10. **Ideias & Aprendizado**: Projetos embrionários, cursos, workshops

11. **Governança**: Auditoria, gestão de usuários, importação de dados

12. **Interface**: Tema claro/escuro, responsivo, logo FUNCEF com brilho azul

## Banco de Dados (Supabase/PostgreSQL):
Tabelas: profiles, sprints, sprint_entregas, subtarefas, task_tags, task_comments, task_attachments, checklist_items, calendar_events, event_members, sprint_reviews, sprint_review_items, pa_items, pa_om_status, riscos, ideias, reminder_log, audit_log

## Integrações existentes:
- Supabase (DB + Auth + Storage)
- API Claude Anthropic (chamadas do browser para IA)
- Microsoft Teams (webhooks + Adaptive Cards)
- Resend (e-mail API)
- Supabase Edge Functions (Deno) para automação

## Restrições:
- Sprint 1 finalizada (não alterar)
- Sprint 2 planejada (não alterar registros)
- Plano de Ação = apenas aba "Gestão de Benefício" (62 subações)
- App de uso interno do NID/COBEN/FUNCEF
- Chave anon Supabase pública (protegida por RLS)

## O que preciso agora:
[DESCREVA AQUI O QUE VOCÊ QUER FAZER — exemplo: "Quero integrar o app com Microsoft 365 usando Power Automate para lembretes e Teams Tabs para embed"]

Por favor, considere todo o contexto acima ao me ajudar. Mantenha a consistência com a arquitetura existente (arquivo único HTML, Supabase, identidade visual FUNCEF). Quando sugerir código, use JavaScript vanilla (sem frameworks) e o padrão CSS já existente do projeto.
```

---

## Como Usar Este Prompt

1. **Copie** o bloco de texto acima (entre as ``` ```)
2. **Cole** no Copilot, ChatGPT, Gemini ou outro assistente
3. **Substitua** o trecho `[DESCREVA AQUI O QUE VOCÊ QUER FAZER]` pela sua necessidade específica
4. O assistente terá contexto completo do projeto para te ajudar com consistência

### Exemplos de uso:
- "Quero adicionar uma aba de OKRs com vinculação às sprints"
- "Quero integrar com Microsoft Graph API para SSO e SharePoint"
- "Quero adicionar gráficos de burndown com Chart.js"
- "Quero criar um PWA para acesso offline"
- "Quero migrar o backend de Supabase para Azure"

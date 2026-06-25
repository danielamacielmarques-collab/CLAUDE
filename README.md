# NID/COBEN — Agile Board v4

Aplicação de gestão ágil das sprints do Núcleo de Inovação e Dados (NID) da
COBEN/FUNCEF. Arquivo único (`index.html`), inspiração ClickUp, identidade
visual FUNCEF, com login real (Supabase Auth) e modo claro/escuro.

## Funcionalidades

- **Autenticação real** — login com e-mail e senha via Supabase Auth, com
  cadastro de novos usuários direto da tela.
- **Usuários viram tags de responsáveis** — todo cadastro cria automaticamente
  um *profile* que pode ser atribuído como executor / revisor / observador em
  tarefas e entregas.
- **Edição de perfil** — nome, iniciais, cor, área e cargo.
- **Tema claro / escuro** — toggle persistido em `localStorage`.
- **Sidebar de sprints 2026–2027** com indicador de risco e % de conclusão.
- **6 visões**: Dashboard, Kanban, Backlog (por fase), Calendário, Equipe,
  Reviews.
- **Filtro por fase do ciclo** — Ideação → Business Case → Planejamento →
  Execução → Homologação → Implantação → Encerramento (inspirado nas imagens
  de referência).
- **Cards estilo ClickUp** — barra de prioridade colorida, tags coloridas,
  avatares empilhados, contador de checklist, story points, progresso, datas.
- **Modal de tarefa com 5 abas**: Detalhes, Equipe, Tags, Checklist,
  Cronograma.
- **Calendário mensal** com eventos de subtarefas e entregas planejadas.
- **Reviews por sprint** — NPS, velocidade, % entregue, entregas, riscos,
  próximas ações.
- **Logo FUNCEF com fundo transparente** e brilho azul institucional.

## Setup

### 1) Banco — Supabase
1. Abra o projeto Supabase em `https://supabase.com/dashboard/project/oclmebkrgazsrujnaywg`.
2. SQL Editor → cole e execute o conteúdo de `schema.sql`.
3. (Comentários + anexos + checklist/tags em entregas) Execute `schema_addon.sql`.
4. (Tipos de usuário + admin + auditoria) Execute `schema_addon_v7.sql`.
   - Promove automaticamente `daniela.ribas@funcef.com.br` a admin.
   - Cria tabela `audit_log`.
   - Adiciona coluna `tipo` em `profiles`: admin, integrante, gestor, coordenador, visitante.
5. (Calendário com eventos custom) Execute `schema_addon_v8.sql`.
   - Cria tabelas `calendar_events` e `event_members`.
   - Insere o "Weekly do Núcleo de Dados" como evento recorrente padrão.
6. (Anexos e comentários em eventos) Execute `schema_addon_v9.sql`.
   - Adiciona coluna `evento_id` em `task_attachments` e `task_comments`.
   - Permite anexar atas, loop de temas, slides nas reuniões.
7. (Exclusão de usuário pelo admin) Execute `schema_addon_v10.sql`.
   - Cria função RPC `delete_user_admin` (security definer).
   - Permite que admin exclua permanentemente usuários do auth.users.
8. (Weekly do Núcleo em quinta-feira 15h) Execute `schema_addon_v11.sql`.
   - Atualiza o evento Weekly para 2026-06-04 (quinta) às 15h.
9. (Anexos e comentários por ocorrência da recorrente) Execute `schema_addon_v12.sql`.
   - Adiciona `evento_data` em task_attachments e task_comments.
   - Cada quinta-feira do Weekly tem ata/comentários próprios.
10. Em **Authentication → Providers → Email** desabilite "Confirm email".

### 2) Rodar localmente
Abra `index.html` direto no navegador, ou:
```bash
python3 -m http.server 8080
# http://localhost:8080
```

### 3) Deploy — Netlify
1. Arraste a pasta para `app.netlify.com` → Sites.
2. O `netlify.toml` já configura o redirect SPA.

## Estrutura

```
.
├── index.html      ← App completo (HTML + CSS + JS + logo base64)
├── logo.png        ← Logo FUNCEF transparente
├── schema.sql      ← Schema do banco (profiles + Auth + sprints + tarefas)
├── netlify.toml    ← SPA redirect
└── README.md
```

## Paleta FUNCEF

- Azul institucional: `#2B6AFF`
- Laranja institucional: `#FF7B39`
- Sucesso: `#22D172` | Atenção: `#F5A524` | Crítico: `#FF4757`

## Notas de segurança

- A chave anon Supabase é pública por design.
- RLS habilitado: leitura/escrita exige `auth.role() = 'authenticated'`.
- Para uso interno do núcleo. Para produção pública, refinar políticas RLS por
  usuário/owner.

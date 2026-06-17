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
3. (Anexos + comentários) SQL Editor → cole e execute `schema_addon.sql`.
   Este script cria as tabelas `task_comments`, `task_attachments` e o bucket
   de Storage `task-files`. É idempotente (pode rodar várias vezes).
4. Em **Authentication → Providers → Email** garanta que esteja habilitado.
   Para evitar a etapa de confirmação por e-mail durante o uso interno,
   desabilite "Confirm email".

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

# Manual de Instalacao — NID/COBEN Agile Board

## Guia completo para replicar a solucao do zero

Este manual ensina como colocar o aplicativo de gestao agil do NID/COBEN no ar, do zero, mesmo sem experiencia tecnica. Siga cada passo na ordem.

---

## O que voce vai precisar

- Um navegador de internet (Chrome, Edge, Firefox)
- Uma conta de e-mail
- Cerca de 30 minutos

---

## PARTE 1 — Criar o banco de dados (Supabase)

O Supabase e o servico que guarda todos os dados do aplicativo (usuarios, tarefas, sprints, etc). Ele e gratuito para uso basico.

### Passo 1: Criar conta no Supabase

1. Acesse [https://supabase.com](https://supabase.com)
2. Clique em **"Start your project"** (ou "Sign Up")
3. Faca login com sua conta do GitHub ou crie uma conta com e-mail e senha
4. Apos o login, voce vera o painel do Supabase

### Passo 2: Criar um novo projeto

1. Clique em **"New Project"**
2. Preencha:
   - **Name**: `nid-coben-board` (ou qualquer nome que quiser)
   - **Database Password**: escolha uma senha forte e **anote ela** (voce nao vai precisar no dia a dia, mas guarde)
   - **Region**: `South America (Sao Paulo)` — escolha a mais proxima de voce
3. Clique em **"Create new project"**
4. Aguarde 1-2 minutos enquanto o projeto e criado

### Passo 3: Anotar as credenciais do projeto

1. No painel do projeto, clique em **Settings** (icone de engrenagem) no menu lateral
2. Clique em **API** (dentro de "Project Settings")
3. Voce vera duas informacoes importantes — **copie e guarde as duas**:
   - **Project URL**: algo como `https://xxxxxxxxxxx.supabase.co`
   - **anon public key**: uma chave longa que comeca com `eyJ...`

> Essas duas informacoes serao usadas para conectar o aplicativo ao banco de dados.

### Passo 4: Configurar o e-mail (desabilitar confirmacao)

1. No menu lateral, clique em **Authentication**
2. Clique em **Providers**
3. Clique em **Email**
4. **Desabilite** a opcao **"Confirm email"** (coloque o toggle em OFF)
5. Clique em **Save**

> Isso permite que usuarios se cadastrem e ja entrem direto, sem precisar confirmar o e-mail.

### Passo 5: Criar as tabelas do banco de dados

Aqui voce vai rodar os scripts SQL que criam toda a estrutura do banco. Sao 12 scripts, e devem ser executados **na ordem**.

1. No menu lateral do Supabase, clique em **SQL Editor**
2. Clique em **"New query"** (botao no canto superior)

**Para cada script abaixo, faca o seguinte:**
- Abra o arquivo `.sql` correspondente (esta na pasta que voce recebeu)
- Selecione **todo o conteudo** do arquivo (Ctrl+A)
- Cole no SQL Editor do Supabase (Ctrl+V)
- Clique no botao **"Run"** (ou pressione Ctrl+Enter)
- Aguarde a mensagem **"Success"** aparecer
- Apague o conteudo e repita com o proximo arquivo

**Ordem de execucao (OBRIGATORIA):**

| # | Arquivo | O que faz |
|---|---------|-----------|
| 1 | `schema.sql` | Cria as tabelas base: usuarios, tags, tarefas, sprints, reviews |
| 2 | `schema_addon.sql` | Adiciona comentarios, anexos e checklist em entregas |
| 3 | `schema_addon_v7.sql` | Tipos de usuario (admin, integrante, etc) e auditoria |
| 4 | `schema_addon_v8.sql` | Calendario com eventos e reunioes |
| 5 | `schema_addon_v9.sql` | Anexos e comentarios em eventos do calendario |
| 6 | `schema_addon_v10.sql` | Funcao para admin excluir usuarios |
| 7 | `schema_addon_v11.sql` | Ajuste da Weekly para quinta-feira 15h |
| 8 | `schema_addon_v12.sql` | Anexos por ocorrencia de reuniao recorrente |
| 9 | `schema_addon_v13.sql` | Reviews com historico (multiplas por sprint) |
| 10 | `schema_addon_v14.sql` | Status "despriorizado" e "cancelado" |
| 11 | `schema_addon_v15.sql` | Perfis ricos: foto, bio, habilidades |
| 12 | `schema_addon_v16.sql` | Plano de Acao COBEN |

> **Dica:** Se algum script der erro, verifique se voce rodou os anteriores na ordem certa. Todos sao idempotentes (podem ser rodados mais de uma vez sem problema).

### Passo 6: Criar o bucket de arquivos (Storage)

O bucket e onde ficam os arquivos anexados (atas, documentos, fotos de perfil).

1. No menu lateral, clique em **Storage**
2. Clique em **"New bucket"**
3. Preencha:
   - **Name**: `task-files`
   - **Public bucket**: **SIM** (habilite o toggle)
4. Clique em **"Create bucket"**

Pronto! O banco de dados esta configurado.

---

## PARTE 2 — Configurar o aplicativo

O aplicativo e um unico arquivo HTML. Voce precisa colocar nele as credenciais do seu projeto Supabase.

### Passo 1: Abrir o arquivo index.html

1. Abra o arquivo `index.html` em um **editor de texto** (Bloco de Notas, VS Code, Notepad++, etc)
2. Use **Ctrl+H** (Localizar e Substituir)

### Passo 2: Substituir a URL do Supabase

1. No campo "Localizar", cole:
   ```
   https://oclmebkrgazsrujnaywg.supabase.co
   ```
2. No campo "Substituir por", cole a **sua Project URL** (que voce anotou no Passo 3 da Parte 1)
3. Clique em **"Substituir tudo"**

### Passo 3: Substituir a chave anon

1. No campo "Localizar", cole a chave anon antiga:
   ```
   eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9jbG1lYmtyZ2F6c3J1am5heXdnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODExOTc5NDgsImV4cCI6MjA5Njc3Mzk0OH0.TcxaOvLl_lnI3dViT3xvSweL7ho3tzDVr1Spuc0TtVE
   ```
2. No campo "Substituir por", cole a **sua anon public key** (que voce anotou no Passo 3 da Parte 1)
3. Clique em **"Substituir tudo"**
4. **Salve o arquivo** (Ctrl+S)

> **Importante:** A chave anon e publica por design do Supabase. Ela nao da acesso ao banco sem autenticacao — a seguranca e feita pelo sistema de login (RLS).

### Passo 4: Testar localmente (opcional)

Antes de colocar no ar, voce pode testar no seu computador:
- Simplesmente abra o arquivo `index.html` no navegador (duplo-clique nele)
- Ou, se tiver Python instalado, rode no terminal:
  ```
  python3 -m http.server 8080
  ```
  E acesse `http://localhost:8080`

---

## PARTE 3 — Colocar no ar (Deploy no Netlify)

O Netlify e o servico que hospeda o aplicativo na internet. Tambem e gratuito.

### Passo 1: Criar conta no Netlify

1. Acesse [https://app.netlify.com](https://app.netlify.com)
2. Clique em **"Sign up"**
3. Faca login com GitHub, Google ou e-mail

### Passo 2: Fazer o deploy

1. No painel do Netlify, va em **Sites**
2. Voce vera uma area que diz **"Drag and drop your site output folder here"**
3. Crie uma pasta no seu computador com estes 3 arquivos:
   - `index.html` (ja com suas credenciais Supabase)
   - `logo.png`
   - `netlify.toml`
4. **Arraste a pasta inteira** para a area de upload do Netlify
5. Aguarde o deploy (leva poucos segundos)

### Passo 3: Acessar o site

1. Apos o deploy, o Netlify vai gerar um link como:
   `https://nome-aleatorio.netlify.app`
2. Clique no link — seu aplicativo esta no ar!
3. (Opcional) Voce pode mudar o nome do site em **Site settings > Site details > Change site name**

---

## PARTE 4 — Primeiro acesso e configuracao

### Passo 1: Criar o primeiro usuario

1. Acesse o site no navegador
2. Na tela de login, clique em **"Criar conta"**
3. Preencha:
   - **Nome completo**: seu nome
   - **E-mail**: seu e-mail
   - **Senha**: escolha uma senha
4. Clique em **"Cadastrar"**
5. Voce sera logado automaticamente

### Passo 2: Promover a admin

O primeiro usuario precisa ser promovido a admin manualmente:

1. Volte ao **Supabase > SQL Editor**
2. Cole e execute:
   ```sql
   UPDATE profiles SET tipo = 'admin' WHERE email = 'SEU_EMAIL_AQUI';
   ```
   (substitua `SEU_EMAIL_AQUI` pelo e-mail que voce usou no cadastro)
3. Faca **logout e login novamente** no aplicativo

Agora voce e admin e pode:
- Gerenciar usuarios (menu do perfil > Gestao de Usuarios)
- Mudar tipos (admin, integrante, gestor, coordenador, visitante)
- Excluir usuarios
- Ver log de auditoria

### Passo 3: Convidar a equipe

Cada pessoa da equipe faz o proprio cadastro pela tela de login. Depois, voce como admin pode ajustar o tipo de cada um na Gestao de Usuarios.

---

## PARTE 5 — Estrutura dos arquivos

```
pasta-do-projeto/
├── index.html              ← Aplicativo completo (HTML + CSS + JS)
├── logo.png                ← Logo FUNCEF com fundo transparente
├── netlify.toml            ← Configuracao de redirect para o Netlify
├── schema.sql              ← Tabelas base do banco
├── schema_addon.sql        ← Comentarios, anexos, checklist
├── schema_addon_v7.sql     ← Tipos de usuario e auditoria
├── schema_addon_v8.sql     ← Calendario com eventos
├── schema_addon_v9.sql     ← Anexos em eventos
├── schema_addon_v10.sql    ← Exclusao de usuario (admin)
├── schema_addon_v11.sql    ← Weekly quinta 15h
├── schema_addon_v12.sql    ← Anexos por ocorrencia
├── schema_addon_v13.sql    ← Reviews com historico
├── schema_addon_v14.sql    ← Status despriorizado/cancelado
├── schema_addon_v15.sql    ← Perfis ricos (foto, bio, skills)
├── schema_addon_v16.sql    ← Plano de Acao COBEN
└── MANUAL_INSTALACAO.md    ← Este manual
```

---

## PARTE 6 — Funcionalidades do aplicativo

### Visoes disponiveis

| Visao | O que faz |
|-------|-----------|
| Sobre o Nucleo | Apresenta o NID: objetivo, diretrizes, 8 eixos, 22 projetos |
| Dashboard | Painel da sprint com metricas, filtros por tipo e eixo |
| Kanban | Quadro visual com colunas por status (arrastar e soltar) |
| Backlog | Lista de tarefas agrupadas por fase do ciclo |
| Calendario | Visao mensal com eventos, reunioes e prazos |
| Equipe | Cards dos integrantes com foto, skills, entregas |
| Reviews | Historico de reviews por sprint com disposicao por entrega |
| Plano de Acao | 62 subacoes de Gestao de Beneficio vinculadas as sprints |

### Tipos de usuario

| Tipo | Permissoes |
|------|-----------|
| Admin | Tudo: gerenciar usuarios, excluir, mudar tipos |
| Integrante | Criar e editar tarefas, entregas, reviews |
| Gestor | Igual ao integrante |
| Coordenador | Igual ao integrante |
| Visitante | Apenas visualizacao |

### Status das atividades

| Status | Cor | Conta no progresso? |
|--------|-----|---------------------|
| Pendente | Cinza | Sim |
| Em andamento | Amarelo | Sim |
| Em revisao | Azul | Sim |
| Concluido | Verde | Sim |
| Bloqueado | Vermelho | Sim |
| Despriorizado | Cinza claro | Nao |
| Cancelado | Cinza claro | Nao |

### Indicadores da sprint (sidebar)

| Icone | Significado |
|-------|-------------|
| ✅ | Sprint concluida (100%) |
| ⏱️ | Sprint encerrada (prazo passou) |
| 🔵 | Sprint atual (mes corrente) |
| ⏳ | Sprint futura |

---

## PARTE 7 — Perguntas frequentes

**P: O aplicativo e seguro?**
R: Sim. O Supabase usa autenticacao JWT e Row Level Security (RLS). Ninguem acessa os dados sem estar logado. A chave anon que aparece no codigo e publica por design — ela nao permite nada sem autenticacao.

**P: Quanto custa?**
R: Zero. Tanto o Supabase (plano free) quanto o Netlify (plano starter) sao gratuitos para o volume de uso de uma equipe pequena.

**P: Posso mudar as cores?**
R: Sim. O aplicativo suporta tema claro e escuro (toggle no canto superior). As cores institucionais FUNCEF estao definidas como variaveis CSS e podem ser alteradas no inicio do arquivo index.html.

**P: Como fazer backup dos dados?**
R: No Supabase, va em Settings > Database > Backups. O plano gratuito faz backups automaticos diarios com retencao de 7 dias.

**P: Posso usar um dominio proprio?**
R: Sim. No Netlify, va em Site settings > Domain management > Add custom domain. Voce precisara apontar o DNS do seu dominio para o Netlify.

**P: Posso adicionar mais sprints?**
R: Sim, mas requer edicao do arquivo index.html. As sprints estao definidas no array `SP` dentro do codigo JavaScript. Um desenvolvedor pode adicionar novas entradas seguindo o mesmo formato.

**P: O que fazer se o login nao funciona?**
R: Verifique se voce desabilitou "Confirm email" no Supabase (Parte 1, Passo 4). Se ja desabilitou, verifique se as credenciais (URL e chave anon) estao corretas no index.html.

**P: Posso usar no celular?**
R: Sim. O aplicativo e responsivo e funciona em qualquer navegador de celular.

---

## Suporte

Em caso de duvidas, entre em contato com a equipe do Nucleo de Inovacao e Dados (NID/COBEN).

---

*Manual criado em Julho/2026 — NID/COBEN/FUNCEF*

-- ============================================================
-- NID/COBEN Agile Board v13 — ADDON
-- Reviews completas com histórico e disposição por entrega
-- ============================================================
-- Execute APÓS o schema_addon_v12.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

-- Amplia sprint_reviews: remove unique constraint para permitir múltiplas reviews,
-- adiciona campos de resumo automático e observações gerais
alter table sprint_reviews add column if not exists resumo_dashboard jsonb;
alter table sprint_reviews add column if not exists observacoes text;
alter table sprint_reviews add column if not exists criado_por uuid references profiles(id) on delete set null;
alter table sprint_reviews drop constraint if exists sprint_reviews_sprint_id_key;

-- Tabela de disposição por entrega na review
create table if not exists sprint_review_items (
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

create index if not exists idx_sri_review on sprint_review_items(review_id);
create index if not exists idx_sri_sprint on sprint_review_items(sprint_id, entrega_idx);

-- RLS
alter table sprint_review_items enable row level security;

drop policy if exists sri_read  on sprint_review_items;
drop policy if exists sri_write on sprint_review_items;

create policy sri_read  on sprint_review_items for select using (auth.role() = 'authenticated');
create policy sri_write on sprint_review_items for all    using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

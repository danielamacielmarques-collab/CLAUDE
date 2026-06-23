-- ============================================================
-- NID/COBEN Agile Board v10 — ADDON
-- Exclusão de usuário pelo admin (RPC seguro)
-- ============================================================
-- Execute APÓS o schema_addon_v9.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

-- =====================================================
-- RPC: delete_user_admin
-- Só admin pode chamar; não pode auto-excluir
-- Deleta auth.users → cascateia para profiles (e dependentes)
-- =====================================================
create or replace function delete_user_admin(target_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  caller_tipo text;
begin
  select tipo into caller_tipo from profiles where id = auth.uid();
  if caller_tipo is null or caller_tipo <> 'admin' then
    raise exception 'Apenas administradores podem excluir usuários';
  end if;
  if target_id = auth.uid() then
    raise exception 'Você não pode excluir sua própria conta';
  end if;
  delete from auth.users where id = target_id;
end;
$$;

-- Permissões
revoke all on function delete_user_admin(uuid) from public;
grant execute on function delete_user_admin(uuid) to authenticated;

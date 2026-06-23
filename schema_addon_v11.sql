-- ============================================================
-- NID/COBEN Agile Board v11 — ADDON
-- Ajusta Weekly do Núcleo para QUINTA-FEIRA às 15h
-- ============================================================
-- Execute APÓS o schema_addon_v10.sql
-- Idempotente: pode ser executada várias vezes
-- ============================================================

-- 2026-06-04 é quinta-feira (primeira do ciclo Jun/26 → Mai/27)
update calendar_events
   set data         = '2026-06-04',
       hora_inicio  = '15:00',
       hora_fim     = '16:00',
       duracao_min  = 60,
       recorrencia  = 'semanal',
       recorrente   = true,
       descricao    = 'Reunião semanal do NID — toda quinta-feira às 15h'
 where tipo = 'weekly';

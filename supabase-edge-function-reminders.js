// ============================================================
// NID/COBEN Agile Board — Supabase Edge Function: send-reminders
// ============================================================
// Esta funcao envia lembretes automaticos por Teams e/ou e-mail.
// Deploy: supabase functions deploy send-reminders
//
// Secrets necessarios:
//   TEAMS_WEBHOOK_URL  — URL do webhook do Teams
//   RESEND_API_KEY     — Chave da API do Resend (resend.com)
//   EMAIL_TO           — Destinatarios (separados por virgula)
//   EMAIL_FROM         — Remetente (ex: nid@funcef.com.br)
//
// Schedule (pg_cron no SQL Editor):
//   select cron.schedule('nid-lembretes', '0 11 * * 1-5',
//     $$select net.http_post(
//       url := 'https://SEU-PROJECT.supabase.co/functions/v1/send-reminders',
//       headers := '{"Authorization":"Bearer SEU-ANON-KEY"}'::jsonb,
//       body := '{}'::jsonb
//     );$$
//   );
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const TEAMS_WEBHOOK = Deno.env.get('TEAMS_WEBHOOK_URL');
const RESEND_KEY = Deno.env.get('RESEND_API_KEY');
const EMAIL_TO = Deno.env.get('EMAIL_TO') || '';
const EMAIL_FROM = Deno.env.get('EMAIL_FROM') || 'NID COBEN <nid@funcef.com.br>';

Deno.serve(async (req) => {
  try {
    const db = createClient(SUPABASE_URL, SUPABASE_KEY);
    const today = new Date().toISOString().slice(0, 10);
    const in3d = new Date(Date.now() + 3 * 86400000).toISOString().slice(0, 10);

    // Buscar dados
    const [taskRes, eventRes, profileRes] = await Promise.all([
      db.from('subtarefas').select('*'),
      db.from('calendar_events').select('*'),
      db.from('profiles').select('id, nome'),
    ]);

    const tasks = taskRes.data || [];
    const events = eventRes.data || [];
    const profiles = profileRes.data || [];
    const nameOf = (id) => {
      const p = profiles.find(p => p.id === id);
      return p ? p.nome.split(' ')[0] : '';
    };

    // Tarefas atrasadas
    const atrasadas = tasks.filter(t =>
      t.status !== 'concluido' && t.data_fim && t.data_fim < today
    );

    // Tarefas com prazo nos proximos 3 dias
    const proximas = tasks.filter(t =>
      t.status !== 'concluido' && t.data_fim && t.data_fim >= today && t.data_fim <= in3d
    );

    // Reunioes de hoje
    const dayOfWeek = new Date(today + 'T12:00:00').getDay();
    const reunioes = events.filter(ev => {
      if (!ev.data) return false;
      if (ev.recorrencia === 'semanal') {
        return new Date(ev.data + 'T12:00:00').getDay() === dayOfWeek;
      }
      return ev.data === today;
    });

    // Se nao ha nada relevante, nao envia
    if (!atrasadas.length && !proximas.length && !reunioes.length) {
      return new Response(JSON.stringify({ message: 'Nenhum lembrete para enviar' }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Montar mensagem
    let msg = `🔔 **LEMBRETE NID/COBEN**\n`;
    msg += `📅 ${new Date().toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: 'long', year: 'numeric' })}\n\n`;

    if (atrasadas.length) {
      msg += `🚨 **TAREFAS ATRASADAS (${atrasadas.length})**\n`;
      atrasadas.forEach(t => {
        const resp = nameOf(t.criado_por);
        msg += `- ${(t.titulo || '').replace(/^\[.*?\]\s*/, '').slice(0, 80)}`;
        if (t.data_fim) msg += ` · Prazo: ${t.data_fim}`;
        if (resp) msg += ` · ${resp}`;
        msg += '\n';
      });
      msg += '\n';
    }

    if (proximas.length) {
      msg += `⏰ **PRAZO NOS PRÓXIMOS 3 DIAS (${proximas.length})**\n`;
      proximas.forEach(t => {
        const resp = nameOf(t.criado_por);
        msg += `- ${(t.titulo || '').replace(/^\[.*?\]\s*/, '').slice(0, 80)}`;
        if (t.data_fim) msg += ` · Prazo: ${t.data_fim}`;
        if (resp) msg += ` · ${resp}`;
        msg += '\n';
      });
      msg += '\n';
    }

    if (reunioes.length) {
      msg += `📅 **REUNIÕES DE HOJE (${reunioes.length})**\n`;
      reunioes.forEach(ev => {
        msg += `- ${ev.titulo} (${ev.hora_inicio || '—'})\n`;
      });
      msg += '\n';
    }

    msg += '---\n_Enviado automaticamente pelo NID Agile Board_';

    const results = [];

    // Enviar para Teams
    if (TEAMS_WEBHOOK) {
      const card = {
        type: 'message',
        attachments: [{
          contentType: 'application/vnd.microsoft.card.adaptive',
          contentUrl: null,
          content: {
            '$schema': 'http://adaptivecards.io/schemas/adaptive-card.json',
            type: 'AdaptiveCard',
            version: '1.4',
            body: [
              { type: 'TextBlock', text: '🔔 Lembrete NID/COBEN', size: 'ExtraLarge', weight: 'Bolder', color: 'Accent' },
              { type: 'TextBlock', text: msg.replace(/\*\*/g, ''), wrap: true },
            ],
          },
        }],
      };
      const resp = await fetch(TEAMS_WEBHOOK, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(card),
      });
      results.push({ channel: 'teams', status: resp.ok ? 'ok' : 'error', code: resp.status });
    }

    // Enviar e-mail via Resend
    if (RESEND_KEY && EMAIL_TO) {
      const emails = EMAIL_TO.split(',').map(e => e.trim()).filter(e => e.includes('@'));
      if (emails.length) {
        const htmlBody = msg
          .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
          .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
          .replace(/^- (.+)$/gm, '<div style="padding-left:1rem">• $1</div>')
          .replace(/\n\n/g, '<br><br>').replace(/\n/g, '<br>');

        const resp = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${RESEND_KEY}`,
          },
          body: JSON.stringify({
            from: EMAIL_FROM,
            to: emails,
            subject: `🔔 Lembrete NID/COBEN — ${new Date().toLocaleDateString('pt-BR')}`,
            html: `<div style="font-family:Arial,sans-serif;max-width:700px;margin:0 auto;padding:20px">${htmlBody}</div>`,
          }),
        });
        results.push({ channel: 'email', status: resp.ok ? 'ok' : 'error', code: resp.status });
      }
    }

    // Registrar no log de auditoria
    await db.from('audit_log').insert({
      action: 'lembrete_automatico',
      entity_type: 'lembrete',
      summary: `Lembrete automático: ${atrasadas.length} atrasadas, ${proximas.length} próximas, ${reunioes.length} reuniões`,
    });

    return new Response(JSON.stringify({
      message: 'Lembretes enviados',
      atrasadas: atrasadas.length,
      proximas: proximas.length,
      reunioes: reunioes.length,
      results,
    }), { headers: { 'Content-Type': 'application/json' } });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});

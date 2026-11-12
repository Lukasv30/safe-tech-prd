import { createClient } from 'npm:@supabase/supabase-js@2';

type Evento = 'SEM_SINAL' | 'FALHA' | 'MOVIMENTO_SUSPEITO' | 'RUIDO_ALTO' | 'NORMALIZADO';

const REGRAS: Record<Evento, { gravidade: 'BAIXA' | 'MEDIA' | 'ALTA' | 'CRITICA' | null; statusEquip: string | null }> = {
  SEM_SINAL:          { gravidade: 'MEDIA', statusEquip: 'INOPERANTE' },
  FALHA:              { gravidade: 'ALTA',  statusEquip: 'INOPERANTE' },
  MOVIMENTO_SUSPEITO: { gravidade: 'ALTA',  statusEquip: null },
  RUIDO_ALTO:         { gravidade: 'MEDIA', statusEquip: null },
  NORMALIZADO:        { gravidade: null,    statusEquip: 'OPERANTE' },
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ erro: 'Use POST' }, 405);

  // Autenticação do dispositivo: segredo compartilhado no cabeçalho
  const segredo = req.headers.get('x-device-secret');
  if (!segredo || segredo !== Deno.env.get('DEVICE_SECRET')) return json({ erro: 'Não autorizado' }, 401);

  let corpo: { codigo?: string; evento?: Evento; mensagem?: string };
  try { corpo = await req.json(); } catch { return json({ erro: 'JSON inválido' }, 400); }

  const { codigo, evento, mensagem } = corpo;
  if (!codigo || !evento || !(evento in REGRAS)) {
    return json({ erro: 'Informe codigo e evento (SEM_SINAL, FALHA, MOVIMENTO_SUSPEITO, RUIDO_ALTO, NORMALIZADO)' }, 400);
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,   // injetado automaticamente pelo Supabase
    { db: { schema: 'safetech' } },
  );

  const { data: equip, error: errEquip } = await supabase
    .from('equipamento').select('id, praca_id, codigo, tipo, localizacao').eq('codigo', codigo).single();
  if (errEquip || !equip) return json({ erro: `Equipamento ${codigo} não encontrado` }, 404);

  const regra = REGRAS[evento];
  if (regra.statusEquip) {
    await supabase.from('equipamento').update({ status: regra.statusEquip }).eq('id', equip.id);
  }

  if (!regra.gravidade) return json({ ok: true, alerta: null, equipamento: equip.codigo, status: regra.statusEquip });

  const texto = mensagem ?? `${evento.replace('_', ' ')} em ${equip.tipo} ${equip.codigo}${equip.localizacao ? ' (' + equip.localizacao + ')' : ''}`;

  const { data: alerta, error: errAlerta } = await supabase
    .from('alerta')
    .insert({ praca_id: equip.praca_id, equipamento_id: equip.id, origem: 'EQUIPAMENTO', gravidade: regra.gravidade, mensagem: texto })
    .select().single();
  if (errAlerta) return json({ erro: errAlerta.message }, 500);

  const { data: equipe } = await supabase.from('usuario').select('id').in('perfil', ['AGENTE', 'GESTOR']).eq('ativo', true);
  if (equipe?.length) {
    await supabase.from('notificacao').insert(
      equipe.map((u) => ({ usuario_id: u.id, alerta_id: alerta.id, titulo: 'Alerta de equipamento', mensagem: texto })),
    );
  }

  return json({ ok: true, alerta }, 201);
});

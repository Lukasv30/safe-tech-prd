#!/usr/bin/env node
// =============================================================================
// SafeTech — teste ponta a ponta da API (Supabase: REST, RPC, Auth, RLS, Storage, Edge Function)
// Uso:  node database/scripts/e2e.mjs
// Lê SUPABASE_URL e SUPABASE_ANON_KEY do .env na raiz (ou do ambiente).
// Opcional: DEVICE_SECRET no ambiente para testar a Edge Function com sucesso.
// Pré-requisitos no projeto: ddl 01..05, seeds, supabase/01..05 e 08, usuários *.demo@safetech.app / Senha@123.
// =============================================================================
import { readFileSync, existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const envFile = resolve(ROOT, '.env');
if (existsSync(envFile)) {
  for (const line of readFileSync(envFile, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*?)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
  }
}
const URL_ = process.env.SUPABASE_URL;
const ANON = process.env.SUPABASE_ANON_KEY;
const DEVICE_SECRET = process.env.DEVICE_SECRET;
if (!URL_ || !ANON) { console.error('Defina SUPABASE_URL e SUPABASE_ANON_KEY (.env na raiz).'); process.exit(2); }

const SENHA = 'Senha@123';
const PRACA_DERBY = 'aaaaaaaa-0000-0000-0000-000000000001';
const results = [];
let failed = 0;

async function call(method, path, { token, body, headers = {}, raw = false } = {}) {
  const h = { apikey: ANON, ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  if (body !== undefined && !raw) h['Content-Type'] = 'application/json';
  const res = await fetch(`${URL_}${path}`, { method, headers: h, body: body === undefined ? undefined : raw ? body : JSON.stringify(body) });
  const text = await res.text();
  let json; try { json = JSON.parse(text); } catch { json = text; }
  return { status: res.status, json, headers: res.headers };
}
const rest = (path, opts) => call('GET', `/rest/v1/${path}`, { ...opts, headers: { 'Accept-Profile': 'safetech', ...(opts?.headers || {}) } });
const rpc = (fn, body, token) => call('POST', `/rest/v1/rpc/${fn}`, { token, body: body ?? {}, headers: { 'Content-Profile': 'safetech' } });
const write = (method, path, body, token, extra = {}) =>
  call(method, `/rest/v1/${path}`, { token, body, headers: { 'Content-Profile': 'safetech', Prefer: 'return=representation', ...extra } });

function check(grupo, nome, ok, detalhe = '') {
  results.push({ grupo, nome, ok, detalhe: String(detalhe).slice(0, 90) });
  if (!ok) failed++;
  console.log(`${ok ? 'OK  ' : 'FAIL'} [${grupo}] ${nome}${detalhe ? '  → ' + String(detalhe).slice(0, 120) : ''}`);
}
const msg = (r) => (typeof r.json === 'object' && r.json ? r.json.message || r.json.msg || r.json.erro || JSON.stringify(r.json) : r.json);

async function login(user) {
  const r = await call('POST', '/auth/v1/token?grant_type=password', { body: { email: `${user}.demo@safetech.app`, password: SENHA } });
  check('auth', `login ${user}.demo@safetech.app`, r.status === 200 && r.json.access_token, r.status === 200 ? 'token ok' : msg(r));
  return r.json.access_token;
}

// -----------------------------------------------------------------------------
// 1. Anônimo
// -----------------------------------------------------------------------------
console.log(`\n== SafeTech E2E contra ${URL_}\n`);
let r = await rest('praca?select=id,nome&order=nome');
check('anon', 'GET praca (leitura pública)', r.status === 200 && r.json.length >= 3, `${r.status} / ${Array.isArray(r.json) ? r.json.length + ' praças' : msg(r)}`);
r = await rest('categoria_ocorrencia?select=id,nome&order=id');
check('anon', 'GET categoria_ocorrencia', r.status === 200 && r.json.length >= 9, `${r.status} / ${Array.isArray(r.json) ? r.json.length + ' categorias' : msg(r)}`);
const CAT_ILUM = Array.isArray(r.json) ? r.json.find((c) => c.nome.startsWith('Ilumina'))?.id : undefined;
r = await rest('vw_praca_resumo?select=nome,ocorrencias_abertas,alertas_novos');
check('anon', 'GET vw_praca_resumo (dashboard)', r.status === 200 && r.json.length >= 3, `${r.status} / ${Array.isArray(r.json) ? JSON.stringify(r.json[0]) : msg(r)}`);
r = await rest('equipamento?select=id');
check('anon', 'GET equipamento bloqueado sem login', r.status === 401 || (r.status === 200 && r.json.length === 0), `${r.status}`);
r = await rest('ocorrencia?select=id');
check('anon', 'GET ocorrencia bloqueado sem login', r.status === 401 || (r.status === 200 && r.json.length === 0), `${r.status}`);
r = await rest('vw_alerta_pendente?select=id');
check('anon', 'GET vw_alerta_pendente bloqueado sem login', r.status === 401 || r.status === 403 || (r.status === 200 && r.json.length === 0), `${r.status}`);

r = await rpc('consultar_protocolo', { p_protocolo: 'STC-2026-000001' });
check('anon', 'RPC consultar_protocolo (seed)', r.status === 200 && r.json && r.json.protocolo === 'STC-2026-000001', `${r.status} / ${r.json?.status ?? msg(r)}`);
r = await rpc('consultar_protocolo', { p_protocolo: 'STC-1999-999999' });
check('anon', 'RPC consultar_protocolo inexistente → null', r.status === 200 && (r.json === null || r.json === ''), `${r.status} / ${JSON.stringify(r.json)}`);

r = await rpc('registrar_ocorrencia', { p_praca_id: PRACA_DERBY, p_categoria_id: CAT_ILUM, p_titulo: '[E2E] Ocorrência anônima', p_descricao: 'Teste automatizado ponta a ponta (anônimo).', p_anonima: true });
const ocAnon = Array.isArray(r.json) ? r.json[0] : null;
check('anon', 'RPC registrar_ocorrencia anônima', r.status === 200 && ocAnon?.protocolo, `${r.status} / ${ocAnon?.protocolo ?? msg(r)}`);
r = await rpc('registrar_ocorrencia', { p_praca_id: PRACA_DERBY, p_categoria_id: CAT_ILUM, p_titulo: '[E2E] identificada sem login', p_descricao: 'deve falhar', p_anonima: false });
check('anon', 'RPC registrar_ocorrencia identificada sem login → 42501', r.status >= 400 && /autenticad/i.test(msg(r)), `${r.status} / ${msg(r)}`);
r = await rpc('acionar_botao_panico', { p_equipamento_codigo: 'BTN-DERBY-01', p_mensagem: '[E2E] Botão de pânico de teste' });
const alertaPanico = Array.isArray(r.json) ? r.json[0] : null;
check('anon', 'RPC acionar_botao_panico (BTN-DERBY-01)', r.status === 200 && alertaPanico?.id && alertaPanico.gravidade === 'CRITICA', `${r.status} / ${alertaPanico?.status ?? msg(r)}`);
r = await rpc('acionar_botao_panico', { p_equipamento_codigo: 'CAM-DERBY-01' });
check('anon', 'RPC acionar_botao_panico em câmera → erro', r.status >= 400, `${r.status} / ${msg(r)}`);
r = await rpc('minhas_ocorrencias', {});
check('anon', 'RPC minhas_ocorrencias sem login → bloqueado', r.status >= 400, `${r.status} / ${msg(r)}`);
r = await rpc('atualizar_status_ocorrencia', { p_ocorrencia_id: ocAnon?.id, p_status: 'EM_ANALISE' });
check('anon', 'RPC atualizar_status_ocorrencia sem login → bloqueado', r.status >= 400, `${r.status} / ${msg(r)}`);

// -----------------------------------------------------------------------------
// 2. Login dos 4 perfis
// -----------------------------------------------------------------------------
const tk = {};
for (const u of ['cidadao', 'agente', 'gestor', 'admin']) tk[u] = await login(u);
for (const [u, perfil] of [['cidadao', 'CIDADAO'], ['agente', 'AGENTE'], ['gestor', 'GESTOR'], ['admin', 'ADMIN']]) {
  r = await rpc('perfil_atual', {}, tk[u]);
  check('auth', `perfil_atual() de ${u} = ${perfil}`, r.status === 200 && r.json === perfil, `${r.status} / ${JSON.stringify(r.json)}`);
}
r = await rest('usuario?select=id,nome,email,perfil', { token: tk.cidadao });
const meuId = Array.isArray(r.json) ? r.json[0]?.id : undefined;
check('auth', 'trigger Auth → usuario: cidadão vê só o próprio perfil', r.status === 200 && r.json.length === 1 && r.json[0].perfil === 'CIDADAO', `${r.status} / ${Array.isArray(r.json) ? JSON.stringify(r.json[0]) : msg(r)}`);
r = await rest('usuario?select=id', { token: tk.gestor });
check('auth', 'gestor vê todos os usuários', r.status === 200 && r.json.length >= 4, `${r.status} / ${Array.isArray(r.json) ? r.json.length + ' usuários' : msg(r)}`);

// -----------------------------------------------------------------------------
// 3. Cidadão
// -----------------------------------------------------------------------------
r = await rpc('registrar_ocorrencia', { p_praca_id: PRACA_DERBY, p_categoria_id: CAT_ILUM, p_titulo: '[E2E] Ocorrência do cidadão', p_descricao: 'Teste automatizado ponta a ponta (cidadão).', p_gravidade: 'MEDIA' }, tk.cidadao);
const ocCid = Array.isArray(r.json) ? r.json[0] : null;
check('cidadao', 'RPC registrar_ocorrencia identificada', r.status === 200 && ocCid?.protocolo && ocCid.status === 'ABERTA', `${r.status} / ${ocCid?.protocolo ?? msg(r)}`);
r = await rpc('minhas_ocorrencias', {}, tk.cidadao);
check('cidadao', 'RPC minhas_ocorrencias contém a recém-criada', r.status === 200 && Array.isArray(r.json) && r.json.some((o) => o.id === ocCid?.id), `${r.status} / ${Array.isArray(r.json) ? r.json.length + ' ocorrências' : msg(r)}`);
r = await rest('ocorrencia?select=id,anonima,autor_id', { token: tk.cidadao });
check('cidadao', 'RLS: GET ocorrencia mostra só não anônimas + as próprias (nenhuma anônima vaza)', r.status === 200 && r.json.every((o) => !o.anonima || o.autor_id === meuId) && !r.json.some((o) => o.id === ocAnon?.id), `${r.status} / ${Array.isArray(r.json) ? r.json.length + ' visíveis' : msg(r)}`);
r = await rest(`historico_ocorrencia?select=status_novo&ocorrencia_id=eq.${ocCid?.id}`, { token: tk.cidadao });
check('cidadao', 'trigger histórico: 1 registro ABERTA na criação', r.status === 200 && r.json.length === 1 && r.json[0].status_novo === 'ABERTA', `${r.status} / ${JSON.stringify(r.json)}`);
r = await rpc('consultar_protocolo', { p_protocolo: ocCid?.protocolo }, tk.cidadao);
check('cidadao', 'RPC consultar_protocolo do próprio registro', r.status === 200 && r.json?.protocolo === ocCid?.protocolo, `${r.status} / ${r.json?.status ?? msg(r)}`);
r = await rpc('atualizar_status_ocorrencia', { p_ocorrencia_id: ocCid?.id, p_status: 'RESOLVIDA' }, tk.cidadao);
check('cidadao', 'RPC atualizar_status_ocorrencia → bloqueado (42501)', r.status >= 400 && /agentes|gestores/i.test(msg(r)), `${r.status} / ${msg(r)}`);
r = await rpc('atribuir_atendimento', { p_ocorrencia_id: ocCid?.id }, tk.cidadao);
check('cidadao', 'RPC atribuir_atendimento → bloqueado', r.status >= 400, `${r.status} / ${msg(r)}`);
r = await rpc('reconhecer_alerta', { p_alerta_id: alertaPanico?.id }, tk.cidadao);
check('cidadao', 'RPC reconhecer_alerta → bloqueado', r.status >= 400, `${r.status} / ${msg(r)}`);
r = await rest('alerta?select=id', { token: tk.cidadao });
check('cidadao', 'RLS: GET alerta vazio', r.status === 200 && r.json.length === 0, `${r.status} / ${Array.isArray(r.json) ? r.json.length : msg(r)}`);
r = await rest('equipamento?select=id', { token: tk.cidadao });
check('cidadao', 'GET equipamento logado lista', r.status === 200 && r.json.length >= 7, `${r.status} / ${Array.isArray(r.json) ? r.json.length + ' equipamentos' : msg(r)}`);
r = await write('PATCH', `praca?id=eq.${PRACA_DERBY}`, { descricao: '[E2E] hack' }, tk.cidadao);
check('cidadao', 'RLS: PATCH praca ignorado (0 linhas)', (r.status === 200 && r.json.length === 0) || r.status === 401 || r.status === 403, `${r.status} / ${Array.isArray(r.json) ? r.json.length + ' linhas' : msg(r)}`);
r = await write('POST', 'avaliacao_praca', { praca_id: PRACA_DERBY, usuario_id: meuId, nota: 4, comentario: '[E2E] avaliação' }, tk.cidadao);
const avaliacaoId = Array.isArray(r.json) ? r.json[0]?.id : undefined;
check('cidadao', 'POST avaliacao_praca como eu mesmo', r.status === 201 && avaliacaoId, `${r.status} / ${avaliacaoId ?? msg(r)}`);
r = await write('POST', 'avaliacao_praca', { praca_id: PRACA_DERBY, usuario_id: '22222222-2222-2222-2222-222222222222', nota: 1 }, tk.cidadao);
check('cidadao', 'RLS: POST avaliacao_praca como outro usuário → bloqueado', r.status === 401 || r.status === 403, `${r.status} / ${msg(r)}`);
if (avaliacaoId) { r = await write('DELETE', `avaliacao_praca?id=eq.${avaliacaoId}`, undefined, tk.cidadao); check('cidadao', 'DELETE da própria avaliação (limpeza)', r.status === 200 && r.json.length === 1, `${r.status}`); }

// Storage
const nomeArq = `e2e/${Date.now()}.txt`;
r = await call('POST', `/storage/v1/object/anexos/${nomeArq}`, { token: tk.cidadao, body: 'teste e2e', raw: true, headers: { 'Content-Type': 'text/plain' } });
check('storage', 'upload no bucket anexos logado', r.status === 200, `${r.status} / ${msg(r)}`);
r = await call('GET', `/storage/v1/object/public/anexos/${nomeArq}`);
check('storage', 'leitura pública do arquivo', r.status === 200 && r.json === 'teste e2e', `${r.status}`);
r = await call('POST', `/storage/v1/object/anexos/e2e/anon.txt`, { body: 'x', raw: true, headers: { 'Content-Type': 'text/plain' } });
check('storage', 'upload sem login → bloqueado', r.status === 400 || r.status === 401 || r.status === 403, `${r.status} / ${msg(r)}`);
r = await call('DELETE', `/storage/v1/object/anexos/${nomeArq}`, { token: tk.agente });
check('storage', 'DELETE por outro usuário → bloqueado', r.status >= 400 || (r.status === 200 && Array.isArray(r.json) && r.json.length === 0), `${r.status}`);
r = await call('DELETE', `/storage/v1/object/anexos/${nomeArq}`, { token: tk.cidadao });
check('storage', 'DELETE pelo dono (limpeza)', r.status === 200, `${r.status} / ${msg(r)}`);

// -----------------------------------------------------------------------------
// 4. Agente
// -----------------------------------------------------------------------------
r = await rest('alerta?select=id,status&order=criado_em.desc', { token: tk.agente });
check('agente', 'RLS: GET alerta lista (inclui o do botão de pânico)', r.status === 200 && r.json.some((a) => a.id === alertaPanico?.id), `${r.status} / ${Array.isArray(r.json) ? r.json.length + ' alertas' : msg(r)}`);
r = await rest('vw_alerta_pendente?select=id,praca_nome', { token: tk.agente });
check('agente', 'GET vw_alerta_pendente', r.status === 200 && Array.isArray(r.json), `${r.status} / ${Array.isArray(r.json) ? r.json.length + ' pendentes' : msg(r)}`);
r = await rest('notificacao?select=titulo&order=criado_em.desc&limit=1', { token: tk.agente });
check('agente', 'notificação do botão de pânico recebida', r.status === 200 && r.json[0]?.titulo === 'Botão de pânico acionado', `${r.status} / ${JSON.stringify(r.json?.[0])}`);
r = await rpc('atribuir_atendimento', { p_ocorrencia_id: ocCid?.id }, tk.agente);
const atend = Array.isArray(r.json) ? r.json[0] : null;
check('agente', 'RPC atribuir_atendimento (assume a ocorrência do cidadão)', r.status === 200 && atend?.id, `${r.status} / ${atend?.id ?? msg(r)}`);
r = await rest(`ocorrencia?select=status&id=eq.${ocCid?.id}`, { token: tk.agente });
check('agente', 'trigger: ocorrência foi para EM_ATENDIMENTO', r.status === 200 && r.json[0]?.status === 'EM_ATENDIMENTO', `${r.status} / ${r.json?.[0]?.status ?? msg(r)}`);
r = await rpc('finalizar_atendimento', { p_atendimento_id: atend?.id, p_relato: '[E2E] Postes trocados.', p_resolver: true }, tk.agente);
check('agente', 'RPC finalizar_atendimento', r.status === 200 && r.json?.[0]?.finalizado_em, `${r.status} / ${r.json?.[0]?.finalizado_em ?? msg(r)}`);
r = await rest(`ocorrencia?select=status,resolvida_em&id=eq.${ocCid?.id}`, { token: tk.agente });
check('agente', 'ocorrência RESOLVIDA com resolvida_em preenchido', r.status === 200 && r.json[0]?.status === 'RESOLVIDA' && r.json[0]?.resolvida_em, `${r.status} / ${JSON.stringify(r.json?.[0])}`);
r = await rest(`historico_ocorrencia?select=status_anterior,status_novo&ocorrencia_id=eq.${ocCid?.id}&order=id`, { token: tk.agente });
check('agente', 'histórico: ABERTA → EM_ATENDIMENTO → RESOLVIDA', r.status === 200 && r.json.length === 3 && r.json[2]?.status_novo === 'RESOLVIDA', `${r.status} / ${Array.isArray(r.json) ? r.json.map((h) => h.status_novo).join('>') : msg(r)}`);
r = await rpc('finalizar_atendimento', { p_atendimento_id: atend?.id, p_relato: 'de novo' }, tk.agente);
check('agente', 'RPC finalizar_atendimento repetido → erro', r.status >= 400, `${r.status} / ${msg(r)}`);
r = await rpc('reconhecer_alerta', { p_alerta_id: alertaPanico?.id }, tk.agente);
check('agente', 'RPC reconhecer_alerta → RECONHECIDO', r.status === 200 && r.json?.[0]?.status === 'RECONHECIDO' && r.json[0]?.reconhecido_por, `${r.status} / ${r.json?.[0]?.status ?? msg(r)}`);
r = await rpc('reconhecer_alerta', { p_alerta_id: alertaPanico?.id, p_status: 'NOVO' }, tk.agente);
check('agente', 'RPC reconhecer_alerta com NOVO → erro', r.status >= 400, `${r.status} / ${msg(r)}`);
r = await write('POST', 'praca', { nome: '[E2E] praça do agente', logradouro: 'x', bairro: 'x', cidade: 'Recife', uf: 'PE', latitude: -8.05, longitude: -34.9 }, tk.agente);
check('agente', 'RLS: POST praca por agente → bloqueado', r.status === 401 || r.status === 403, `${r.status} / ${msg(r)}`);

// -----------------------------------------------------------------------------
// 5. Gestor / Admin
// -----------------------------------------------------------------------------
r = await rpc('atualizar_status_ocorrencia', { p_ocorrencia_id: ocAnon?.id, p_status: 'EM_ANALISE', p_observacao: '[E2E] triagem' }, tk.gestor);
check('gestor', 'RPC atualizar_status_ocorrencia (anônima → EM_ANALISE)', r.status === 200 && r.json?.[0]?.status === 'EM_ANALISE', `${r.status} / ${r.json?.[0]?.status ?? msg(r)}`);
r = await rpc('atualizar_status_ocorrencia', { p_ocorrencia_id: '00000000-0000-0000-0000-000000000000', p_status: 'EM_ANALISE' }, tk.gestor);
check('gestor', 'RPC atualizar_status_ocorrencia inexistente → P0002', r.status >= 400 && /não encontrada/i.test(msg(r)), `${r.status} / ${msg(r)}`);
r = await rpc('reconhecer_alerta', { p_alerta_id: alertaPanico?.id, p_status: 'ENCERRADO' }, tk.gestor);
check('gestor', 'RPC reconhecer_alerta → ENCERRADO com encerrado_em', r.status === 200 && r.json?.[0]?.status === 'ENCERRADO' && r.json[0]?.encerrado_em, `${r.status} / ${r.json?.[0]?.status ?? msg(r)}`);
r = await write('POST', 'praca', { nome: '[E2E] Praça temporária', logradouro: 'Rua de teste', bairro: 'Teste', cidade: 'Recife', uf: 'PE', latitude: -8.05, longitude: -34.9 }, tk.gestor);
const pracaTmp = Array.isArray(r.json) ? r.json[0]?.id : undefined;
check('gestor', 'POST praca por gestor', r.status === 201 && pracaTmp, `${r.status} / ${pracaTmp ?? msg(r)}`);
if (pracaTmp) {
  r = await write('PATCH', `praca?id=eq.${pracaTmp}`, { descricao: '[E2E] editada' }, tk.gestor);
  check('gestor', 'PATCH praca por gestor', r.status === 200 && r.json[0]?.descricao === '[E2E] editada', `${r.status}`);
  r = await write('DELETE', `praca?id=eq.${pracaTmp}`, undefined, tk.admin);
  check('admin', 'DELETE praca por admin (limpeza)', r.status === 200 && r.json.length === 1, `${r.status} / ${msg(r)}`);
}
r = await rest('ocorrencia?select=id,anonima', { token: tk.gestor });
check('gestor', 'RLS: gestor vê ocorrências anônimas', r.status === 200 && r.json.some((o) => o.id === ocAnon?.id), `${r.status} / ${Array.isArray(r.json) ? r.json.length + ' ocorrências' : msg(r)}`);
r = await rest('vw_ocorrencia_aberta?select=protocolo,titulo', { token: tk.gestor });
check('gestor', 'GET vw_ocorrencia_aberta', r.status === 200 && Array.isArray(r.json), `${r.status} / ${Array.isArray(r.json) ? r.json.length + ' abertas' : msg(r)}`);

// -----------------------------------------------------------------------------
// 6. Edge Function evento-equipamento
// -----------------------------------------------------------------------------
r = await call('POST', '/functions/v1/evento-equipamento', { body: { codigo: 'CAM-DERBY-01', evento: 'SEM_SINAL' } });
check('edge', 'POST sem x-device-secret → 401', r.status === 401, `${r.status} / ${msg(r)}`);
r = await call('GET', '/functions/v1/evento-equipamento', { headers: { 'x-device-secret': DEVICE_SECRET || 'x' } });
check('edge', 'GET → 405', r.status === 405, `${r.status} / ${msg(r)}`);
if (DEVICE_SECRET) {
  r = await call('POST', '/functions/v1/evento-equipamento', { body: { codigo: 'CAM-DERBY-01', evento: 'SEM_SINAL', mensagem: '[E2E] câmera sem sinal' }, headers: { 'x-device-secret': DEVICE_SECRET } });
  const alertaEdge = r.json?.alerta;
  check('edge', 'POST SEM_SINAL cria alerta', r.status === 200 && alertaEdge?.id, `${r.status} / ${JSON.stringify(r.json).slice(0, 100)}`);
  r = await rest('equipamento?select=status&codigo=eq.CAM-DERBY-01', { token: tk.agente });
  check('edge', 'equipamento ficou INOPERANTE', r.json?.[0]?.status === 'INOPERANTE', `${r.status} / ${r.json?.[0]?.status}`);
  r = await call('POST', '/functions/v1/evento-equipamento', { body: { codigo: 'CAM-DERBY-01', evento: 'NORMALIZADO' }, headers: { 'x-device-secret': DEVICE_SECRET } });
  check('edge', 'POST NORMALIZADO sem alerta', r.status === 200 && r.json?.alerta === null, `${r.status} / ${JSON.stringify(r.json).slice(0, 100)}`);
  r = await rest('equipamento?select=status&codigo=eq.CAM-DERBY-01', { token: tk.agente });
  check('edge', 'equipamento voltou a OPERANTE', r.json?.[0]?.status === 'OPERANTE', `${r.status} / ${r.json?.[0]?.status}`);
  if (alertaEdge?.id) { r = await rpc('reconhecer_alerta', { p_alerta_id: alertaEdge.id, p_status: 'FALSO_POSITIVO' }, tk.gestor); check('edge', 'alerta da edge encerrado como FALSO_POSITIVO (limpeza)', r.status === 200, `${r.status}`); }
  r = await call('POST', '/functions/v1/evento-equipamento', { body: { codigo: 'NAO-EXISTE', evento: 'FALHA' }, headers: { 'x-device-secret': DEVICE_SECRET } });
  check('edge', 'POST equipamento inexistente → 404', r.status === 404, `${r.status} / ${msg(r)}`);
} else {
  console.log('     (DEVICE_SECRET não definido: testes de sucesso da Edge Function pulados)');
}

// -----------------------------------------------------------------------------
// Resumo
// -----------------------------------------------------------------------------
const total = results.length;
console.log(`\n== Resultado: ${total - failed}/${total} OK${failed ? `, ${failed} FALHAS` : ''}`);
if (process.argv.includes('--md')) {
  console.log('\n| # | Grupo | Teste | Resultado | Detalhe |\n|---|-------|-------|-----------|---------|');
  results.forEach((t, i) => console.log(`| ${i + 1} | ${t.grupo} | ${t.nome} | ${t.ok ? '✅' : '❌'} | ${t.detalhe.replace(/\|/g, '\\|')} |`));
}
process.exit(failed ? 1 : 0);

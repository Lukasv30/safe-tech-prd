# Roteiro — Santhiago Augusto (Desenvolvedor Front-end)

**Objetivo:** um front-end mínimo que prova a conexão ponta a ponta: cadastro/login, lista de praças vinda do
banco, registro de ocorrência via RPC e consulta de protocolo. O visual completo fica para o Checkpoint 3.
**Prazo:** quarta 12/11, PR aberto até 18h.
**Branch:** `feat/cp2-santhiago`
**Depende de:** URL e anon key do Lucas. Até lá, faça os passos 1 e 2.

## Passo 1 — Scaffold

Na raiz do repositório:

```bash
cd src/frontend
npm create vite@latest . -- --template react-ts
npm install
npm install @supabase/supabase-js react-router-dom
```

Crie `src/frontend/.env` (ignorado pelo git) a partir do `.env.example` do Lucas:

```env
VITE_SUPABASE_URL=https://SEU-REF.supabase.co
VITE_SUPABASE_ANON_KEY=sua-anon-key
```

Estrutura alvo:

```text
src/frontend/src/
├── lib/supabase.ts          # cliente único
├── api/auth.ts              # signup, login, logout, sessão
├── api/pracas.ts            # listar praças e resumo
├── api/ocorrencias.ts       # registrar, consultar protocolo, minhas ocorrências
├── pages/Login.tsx
├── pages/Cadastro.tsx
├── pages/Pracas.tsx
├── pages/NovaOcorrencia.tsx
├── pages/Protocolo.tsx
└── App.tsx                  # rotas
```

## Passo 2 — Cliente Supabase

`src/lib/supabase.ts` — **o `schema: 'safetech'` é obrigatório**, senão a API procura as tabelas em `public`.

```ts
import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
if (!url || !anonKey) throw new Error('Configure VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY no .env');

export const supabase = createClient(url, anonKey, { db: { schema: 'safetech' } });
```

## Passo 3 — Camada de API

`src/api/auth.ts` — o `data` do cadastro alimenta a trigger que cria o perfil em `safetech.usuario`.

```ts
import { supabase } from '../lib/supabase';

export async function cadastrar(nome: string, email: string, senha: string, telefone?: string) {
  const { data, error } = await supabase.auth.signUp({
    email, password: senha, options: { data: { nome, telefone } },
  });
  if (error) throw error;
  return data.user;
}

export async function entrar(email: string, senha: string) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password: senha });
  if (error) throw error;
  return data.session;
}

export const sair = () => supabase.auth.signOut();

export async function perfilAtual() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  const { data, error } = await supabase.from('usuario').select('id, nome, email, perfil').eq('id', user.id).single();
  if (error) throw error;
  return data;
}
```

`src/api/pracas.ts`

```ts
import { supabase } from '../lib/supabase';

export type PracaResumo = {
  id: string; nome: string; bairro: string; cidade: string;
  ocorrencias_abertas: number; alertas_novos: number; nota_media_seguranca: number | null;
};

export async function listarPracas(): Promise<PracaResumo[]> {
  const { data, error } = await supabase
    .from('vw_praca_resumo')
    .select('id, nome, bairro, cidade, ocorrencias_abertas, alertas_novos, nota_media_seguranca')
    .order('nome');
  if (error) throw error;
  return data;
}

export async function listarCategorias() {
  const { data, error } = await supabase.from('categoria_ocorrencia').select('id, nome, gravidade_padrao').eq('ativa', true).order('nome');
  if (error) throw error;
  return data;
}
```

`src/api/ocorrencias.ts` — RPCs do Davi.

```ts
import { supabase } from '../lib/supabase';

export type NovaOcorrencia = {
  praca_id: string; categoria_id: number; titulo: string; descricao: string;
  gravidade?: 'BAIXA' | 'MEDIA' | 'ALTA' | 'CRITICA'; anonima?: boolean;
};

export async function registrarOcorrencia(o: NovaOcorrencia) {
  const { data, error } = await supabase.rpc('registrar_ocorrencia', {
    p_praca_id: o.praca_id, p_categoria_id: o.categoria_id, p_titulo: o.titulo,
    p_descricao: o.descricao, p_gravidade: o.gravidade ?? null, p_anonima: o.anonima ?? false,
  });
  if (error) throw error;
  return data[0] as { id: string; protocolo: string; status: string };
}

export async function consultarProtocolo(protocolo: string) {
  const { data, error } = await supabase.rpc('consultar_protocolo', { p_protocolo: protocolo });
  if (error) throw error;
  return data; // null se não existir
}

export async function minhasOcorrencias() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return [];
  const { data, error } = await supabase
    .from('ocorrencia').select('id, protocolo, titulo, status, gravidade, ocorrida_em')
    .eq('autor_id', user.id).order('ocorrida_em', { ascending: false });
  if (error) throw error;
  return data;
}
```

## Passo 4 — Telas (mínimas, sem estilo elaborado)

- **Cadastro.tsx:** nome, e-mail, telefone, senha → `cadastrar()` → redireciona para `/pracas`.
- **Login.tsx:** e-mail, senha → `entrar()`; link para cadastro.
- **Pracas.tsx:** `listarPracas()` em um `useEffect`; tabela com nome, bairro, ocorrências abertas, alertas, nota média.
  Botão "Registrar ocorrência" por praça. **Esta tela é a prova da conexão com o banco.**
- **NovaOcorrencia.tsx:** select de praça e categoria (`listarCategorias()`), título, descrição, gravidade, checkbox
  "anônima" → `registrarOcorrencia()` → mostra o **protocolo** retornado.
- **Protocolo.tsx:** campo de protocolo → `consultarProtocolo()` → mostra status, praça, categoria e a lista do
  histórico (funciona sem login).

Exemplo da lista de praças:

```tsx
import { useEffect, useState } from 'react';
import { listarPracas, type PracaResumo } from '../api/pracas';

export function Pracas() {
  const [pracas, setPracas] = useState<PracaResumo[]>([]);
  const [erro, setErro] = useState<string | null>(null);

  useEffect(() => {
    listarPracas().then(setPracas).catch((e) => setErro(e.message));
  }, []);

  if (erro) return <p>Erro ao carregar praças: {erro}</p>;
  return (
    <table>
      <thead><tr><th>Praça</th><th>Bairro</th><th>Abertas</th><th>Alertas</th><th>Nota</th></tr></thead>
      <tbody>
        {pracas.map((p) => (
          <tr key={p.id}>
            <td>{p.nome}</td><td>{p.bairro}</td><td>{p.ocorrencias_abertas}</td>
            <td>{p.alertas_novos}</td><td>{p.nota_media_seguranca ?? '-'}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
```

Rotas em `App.tsx` com `react-router-dom`: `/login`, `/cadastro`, `/pracas`, `/ocorrencias/nova`, `/protocolo`.
Rotas protegidas: se `supabase.auth.getSession()` vier vazio, redirecione para `/login` (exceto `/protocolo`).

## Passo 5 — Teste de ponta a ponta

1. `npm run dev`, abra o app, cadastre `santhiago.teste@safetech.app`.
2. Confira no painel do Supabase (**Table Editor → safetech → usuario**) que o perfil foi criado.
3. Lista de praças deve mostrar as 3 praças do seed.
4. Registre uma ocorrência; copie o protocolo; consulte em `/protocolo` deslogado.
5. Grave um GIF ou tire prints e salve em `docs/checkpoint-2/evidencias/santhiago-front.md`.

## Passo 6 — Pull Request

Inclua `src/frontend/` (sem `node_modules` e sem `.env`), um `src/frontend/README.md` curto (como rodar) e as
evidências. Peça revisão à Ana. No checkpoint, você demonstra o fluxo cadastro → praças → ocorrência → protocolo.

## Erros comuns

| Erro | Solução |
|------|---------|
| `relation "public.praca" does not exist` | Faltou `{ db: { schema: 'safetech' } }` no `createClient` |
| `permission denied` na lista de praças | Lucas ainda não rodou os grants (06) ou não expôs o schema |
| Cadastro OK mas `perfilAtual()` retorna erro | Trigger do Auth (07) não aplicada |
| `Email not confirmed` no login | Lucas precisa desligar "Confirm email" no painel |
| Lista vazia logado mas cheia deslogado | Política RLS bloqueando; avise o Lucas com o nome da tabela |

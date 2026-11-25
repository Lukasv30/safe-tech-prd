# Roteiro — Santhiago Augusto (Front-end) · Checkpoint 3

**Entrega:** base do app (autenticação com perfil, layout, rotas protegidas, estilo) e as telas do cidadão:
detalhe da praça com avaliação, nova ocorrência com anexo, minhas ocorrências, protocolo com linha do tempo.

**Depende de:** nada para começar. Davi e Lucas dependem de **você**: a base (Passo 1) precisa estar em `main`
até **14h de quarta**, porque Painel, Alertas e Dashboard usam `useAuth()`, `RotaProtegida` e as classes do CSS.

**Como está o código:** todo arquivo abaixo foi compilado com `tsc -b`, passou no `eslint` e no `vite build`
com as versões do seu `package.json`. Copie exatamente; depois adapte à vontade.

> Prazo curto: o roteiro é "copiar, rodar, testar, PR". Não gaste tempo em estilo além do CSS pronto.

## Passo 1 — Base do app (manhã de quarta, PR até 14h)

```bash
git checkout main && git pull
git checkout -b feat/cp3-santhiago
cd src/frontend && npm ci
```

### 1.1 Contexto de autenticação com perfil

Hoje cada tela chama `supabase.auth.getSession()` por conta própria e ninguém sabe o perfil. O contexto
carrega a sessão uma vez, busca o perfil em `usuario` e expõe `ehEquipe` / `ehGestor` para todas as telas.

Crie `src/contexts/AuthContext.tsx`:

```tsx
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';

export type Perfil = 'CIDADAO' | 'AGENTE' | 'GESTOR' | 'ADMIN';
export type Usuario = { id: string; nome: string; email: string; perfil: Perfil };

type AuthState = {
  carregando: boolean;
  session: Session | null;
  usuario: Usuario | null;
  ehEquipe: boolean;   // AGENTE, GESTOR ou ADMIN
  ehGestor: boolean;   // GESTOR ou ADMIN
  sair: () => Promise<void>;
};

const AuthContext = createContext<AuthState | null>(null);

async function carregarUsuario(userId: string): Promise<Usuario | null> {
  const { data, error } = await supabase.from('usuario').select('id, nome, email, perfil').eq('id', userId).single();
  if (error) { console.error('perfil:', error.message); return null; }
  return data as Usuario;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [carregando, setCarregando] = useState(true);
  const [session, setSession] = useState<Session | null>(null);
  const [usuario, setUsuario] = useState<Usuario | null>(null);

  useEffect(() => {
    // onAuthStateChange dispara INITIAL_SESSION logo na assinatura, então cobre o carregamento inicial,
    // o login, o logout e a renovação do token sem precisar de getSession() separado.
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_evento, s) => {
      setSession(s);
      if (s?.user) {
        carregarUsuario(s.user.id).then((u) => { setUsuario(u); setCarregando(false); });
      } else {
        setUsuario(null);
        setCarregando(false);
      }
    });
    return () => subscription.unsubscribe();
  }, []);

  const perfil = usuario?.perfil;
  const valor: AuthState = {
    carregando,
    session,
    usuario,
    ehEquipe: perfil === 'AGENTE' || perfil === 'GESTOR' || perfil === 'ADMIN',
    ehGestor: perfil === 'GESTOR' || perfil === 'ADMIN',
    sair: async () => { await supabase.auth.signOut(); },
  };
  return <AuthContext.Provider value={valor}>{children}</AuthContext.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components -- hook e provider convivem no mesmo arquivo de propósito
export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth precisa estar dentro de <AuthProvider>');
  return ctx;
}
```

### 1.2 Layout com menu por perfil

Crie `src/components/Layout.tsx`. O menu muda conforme o perfil: cidadão vê "Minhas ocorrências", equipe vê
"Painel" e "Alertas", gestor vê "Dashboard".

```tsx
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

export function Layout() {
  const { usuario, ehEquipe, ehGestor, sair } = useAuth();
  const navigate = useNavigate();

  async function logout() {
    await sair();
    navigate('/login');
  }

  return (
    <div className="app">
      <header className="topo">
        <NavLink to="/pracas" className="marca">SafeTech</NavLink>
        <nav>
          <NavLink to="/pracas">Praças</NavLink>
          <NavLink to="/protocolo">Protocolo</NavLink>
          {usuario && !ehEquipe && <NavLink to="/minhas-ocorrencias">Minhas ocorrências</NavLink>}
          {ehEquipe && <NavLink to="/painel">Painel</NavLink>}
          {ehEquipe && <NavLink to="/alertas">Alertas</NavLink>}
          {ehGestor && <NavLink to="/dashboard">Dashboard</NavLink>}
        </nav>
        <div className="sessao">
          {usuario ? (
            <>
              <span title={usuario.email}>{usuario.nome} <small className={`tag tag-${usuario.perfil.toLowerCase()}`}>{usuario.perfil}</small></span>
              <button className="link" onClick={logout}>Sair</button>
            </>
          ) : (
            <NavLink to="/login" className="botao">Entrar</NavLink>
          )}
        </div>
      </header>
      <main className="conteudo">
        <Outlet />
      </main>
      <footer className="rodape">SafeTech · Segurança em Praças Públicas · UNINASSAU 2026.2</footer>
    </div>
  );
}
```

### 1.3 Rota protegida por perfil

Crie `src/components/RotaProtegida.tsx`. Substitui o `Protegida` que está dentro do `App.tsx`.

```tsx
import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth, type Perfil } from '../contexts/AuthContext';

/**
 * Exige login e, opcionalmente, um dos perfis informados.
 * Uso em App.tsx: <Route element={<RotaProtegida perfis={['AGENTE','GESTOR','ADMIN']} />}> ...rotas filhas... </Route>
 */
export function RotaProtegida({ perfis }: { perfis?: Perfil[] }) {
  const { carregando, session, usuario } = useAuth();
  const location = useLocation();

  if (carregando) return <p className="aviso">Carregando...</p>;
  if (!session) return <Navigate to="/login" replace state={{ de: location.pathname }} />;
  if (perfis && usuario && !perfis.includes(usuario.perfil)) {
    return <p className="aviso erro">Seu perfil ({usuario.perfil}) não tem acesso a esta página.</p>;
  }
  return <Outlet />;
}
```

### 1.4 Rotas

Substitua `src/App.tsx`. Note as três páginas que ainda não existem (`Painel`, `Alertas`, `Dashboard`):
crie cada uma como **stub** para o build passar; Davi e Lucas vão substituir os arquivos.

```tsx
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './contexts/AuthContext';
import { Layout } from './components/Layout';
import { RotaProtegida } from './components/RotaProtegida';
import { Login } from './pages/Login';
import { Cadastro } from './pages/Cadastro';
import { Pracas } from './pages/Pracas';
import { DetalhePraca } from './pages/DetalhePraca';
import { NovaOcorrencia } from './pages/NovaOcorrencia';
import { Protocolo } from './pages/Protocolo';
import { MinhasOcorrencias } from './pages/MinhasOcorrencias';
import { Painel } from './pages/Painel';
import { Alertas } from './pages/Alertas';
import { Dashboard } from './pages/Dashboard';

const EQUIPE = ['AGENTE', 'GESTOR', 'ADMIN'] as const;
const GESTAO = ['GESTOR', 'ADMIN'] as const;

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route element={<Layout />}>
            {/* Público */}
            <Route path="/login" element={<Login />} />
            <Route path="/cadastro" element={<Cadastro />} />
            <Route path="/pracas" element={<Pracas />} />
            <Route path="/pracas/:id" element={<DetalhePraca />} />
            <Route path="/protocolo" element={<Protocolo />} />

            {/* Qualquer usuário logado */}
            <Route element={<RotaProtegida />}>
              <Route path="/ocorrencias/nova" element={<NovaOcorrencia />} />
              <Route path="/minhas-ocorrencias" element={<MinhasOcorrencias />} />
            </Route>

            {/* Equipe: agente, gestor, admin */}
            <Route element={<RotaProtegida perfis={[...EQUIPE]} />}>
              <Route path="/painel" element={<Painel />} />
              <Route path="/alertas" element={<Alertas />} />
            </Route>

            {/* Gestão: gestor, admin */}
            <Route element={<RotaProtegida perfis={[...GESTAO]} />}>
              <Route path="/dashboard" element={<Dashboard />} />
            </Route>

            <Route path="*" element={<Navigate to="/pracas" replace />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
```

Stubs (um arquivo para cada: `src/pages/Painel.tsx`, `src/pages/Alertas.tsx`, `src/pages/Dashboard.tsx`):

```tsx
export function Painel() { return <p className="aviso">Painel em construção (Davi).</p>; }
```

```tsx
export function Alertas() { return <p className="aviso">Alertas em construção (Davi).</p>; }
```

```tsx
export function Dashboard() { return <p className="aviso">Dashboard em construção (Lucas).</p>; }
```

### 1.5 Estilo

Substitua `src/index.css` pelo arquivo abaixo e **apague `src/App.css`** (é o boilerplate do Vite; nada o
importa depois desta troca). Troque também em `index.html`: `<html lang="pt-BR">` e
`<title>SafeTech — Segurança em Praças Públicas</title>`.

```css
/* SafeTech — estilo base (sem framework). Tokens em :root; componentes abaixo. */
:root {
  --fundo: #f5f7fa; --superficie: #ffffff; --texto: #1c2430; --suave: #5f6b7a; --borda: #e1e6ec;
  --primaria: #1f5fbf; --primaria-escura: #174a95; --perigo: #c62828; --ok: #2e7d32; --aviso: #ef6c00;
  --baixa: #2e7d32; --media: #f9a825; --alta: #ef6c00; --critica: #c62828;
  --raio: 10px; --sombra: 0 1px 3px rgba(0,0,0,.08);
  font-family: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif; font-size: 15px; line-height: 1.45;
  color: var(--texto); background: var(--fundo);
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--fundo); }
a { color: var(--primaria); text-decoration: none; }
a:hover { text-decoration: underline; }
h1 { font-size: 1.6rem; margin: 0 0 .5rem; }
h2 { font-size: 1.15rem; margin: 1.5rem 0 .5rem; }
h3 { font-size: 1rem; margin: .75rem 0 .35rem; }
code { background: #eef1f5; padding: 0 .3rem; border-radius: 4px; }

/* Layout */
.app { min-height: 100vh; display: flex; flex-direction: column; }
.topo { display: flex; align-items: center; gap: 1.25rem; padding: .6rem 1.25rem; background: var(--superficie); border-bottom: 1px solid var(--borda); position: sticky; top: 0; z-index: 10; flex-wrap: wrap; }
.marca { font-weight: 700; font-size: 1.1rem; color: var(--texto); }
.topo nav { display: flex; gap: .9rem; flex: 1; flex-wrap: wrap; }
.topo nav a { color: var(--suave); padding: .25rem 0; border-bottom: 2px solid transparent; }
.topo nav a.active { color: var(--primaria); border-color: var(--primaria); }
.sessao { display: flex; align-items: center; gap: .75rem; }
.conteudo { flex: 1; width: 100%; max-width: 1100px; margin: 0 auto; padding: 1.25rem; }
.rodape { text-align: center; color: var(--suave); font-size: .8rem; padding: 1rem; }
.estreito { max-width: 560px; margin: 0 auto; }
.titulo-com-acoes { display: flex; justify-content: space-between; align-items: center; gap: 1rem; flex-wrap: wrap; }
.duas-colunas { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 760px) { .duas-colunas { grid-template-columns: 1fr; } }

/* Formulários e botões */
.formulario { display: flex; flex-direction: column; gap: .8rem; background: var(--superficie); padding: 1.25rem; border-radius: var(--raio); box-shadow: var(--sombra); }
.formulario label { display: flex; flex-direction: column; gap: .25rem; font-weight: 600; font-size: .9rem; }
.formulario label.linha { flex-direction: row; align-items: center; gap: .5rem; font-weight: 400; }
.formulario-inline { display: flex; gap: .5rem; align-items: center; flex-wrap: wrap; }
input, select, textarea { font: inherit; padding: .5rem .6rem; border: 1px solid var(--borda); border-radius: 6px; background: #fff; width: 100%; }
.formulario-inline input { width: auto; flex: 1; min-width: 180px; }
input.busca { width: 260px; }
button, .botao { font: inherit; font-weight: 600; padding: .5rem .9rem; border-radius: 6px; border: 1px solid var(--primaria); background: var(--primaria); color: #fff; cursor: pointer; display: inline-block; }
button:hover, .botao:hover { background: var(--primaria-escura); text-decoration: none; }
button:disabled { opacity: .55; cursor: not-allowed; }
button.secundario { background: #fff; color: var(--primaria); }
button.perigo { background: #fff; color: var(--perigo); border-color: var(--perigo); }
button.link { background: none; border: none; color: var(--primaria); padding: 0; font-weight: 500; }
button.link:hover { text-decoration: underline; background: none; }
.acoes { display: flex; gap: .6rem; align-items: center; flex-wrap: wrap; margin-top: .5rem; }
.chip { background: #fff; color: var(--suave); border: 1px solid var(--borda); padding: .3rem .7rem; border-radius: 999px; font-weight: 500; }
.chip.ativo { background: var(--primaria); color: #fff; border-color: var(--primaria); }
.filtros { display: flex; gap: .5rem; flex-wrap: wrap; align-items: center; margin: .5rem 0 1rem; }

/* Avisos e tags */
.aviso { background: var(--superficie); border: 1px solid var(--borda); border-radius: var(--raio); padding: .75rem 1rem; }
.aviso.erro { border-color: var(--perigo); color: var(--perigo); background: #fff5f5; }
.suave { color: var(--suave); }
.perigo-texto { color: var(--perigo); }
.tag { display: inline-block; font-size: .72rem; font-weight: 700; letter-spacing: .02em; padding: .1rem .5rem; border-radius: 999px; background: #e9edf2; color: var(--suave); vertical-align: middle; }
.tag-baixa { background: #e8f5e9; color: var(--baixa); }
.tag-media { background: #fff8e1; color: #9c6f00; }
.tag-alta { background: #fff3e0; color: var(--alta); }
.tag-critica { background: #ffebee; color: var(--critica); }
.tag-operante { background: #e8f5e9; color: var(--ok); }
.tag-inoperante, .tag-desativado { background: #ffebee; color: var(--perigo); }
.tag-em_manutencao { background: #fff3e0; color: var(--alta); }
.tag-cidadao { background: #e3f2fd; color: #1565c0; }
.tag-agente { background: #e8f5e9; color: var(--ok); }
.tag-gestor { background: #f3e5f5; color: #6a1b9a; }
.tag-admin { background: #263238; color: #fff; }
.protocolo { font-size: 1.3rem; letter-spacing: .05em; }

/* Tabelas */
table { width: 100%; border-collapse: collapse; background: var(--superficie); border-radius: var(--raio); overflow: hidden; box-shadow: var(--sombra); font-size: .92rem; }
th, td { text-align: left; padding: .55rem .7rem; border-bottom: 1px solid var(--borda); vertical-align: top; }
th { background: #f0f3f7; font-weight: 600; color: var(--suave); font-size: .8rem; text-transform: uppercase; letter-spacing: .03em; }
tr.selecionada td { background: #f3f7fd; }
tr.detalhe td { background: #fafbfd; }
tr.detalhe textarea { width: 100%; }

/* Cartões / indicadores */
.cartoes { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: .75rem; margin: 1rem 0; }
.cartao { background: var(--superficie); border-radius: var(--raio); padding: .9rem 1rem; box-shadow: var(--sombra); }
.cartao.destaque { border-left: 4px solid var(--alta); }
.cartao-valor { font-size: 1.6rem; font-weight: 700; }
.cartao-rotulo { color: var(--suave); font-size: .85rem; }
.cartao-largo { background: var(--superficie); border-radius: var(--raio); padding: 1rem 1.25rem; box-shadow: var(--sombra); }
.cartao-largo h2:first-child { margin-top: 0; }

/* Praças */
.grade-pracas { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 1rem; margin-top: 1rem; }
.cartao-praca { display: block; background: var(--superficie); border-radius: var(--raio); padding: 1rem 1.1rem; box-shadow: var(--sombra); color: var(--texto); border: 1px solid transparent; }
.cartao-praca:hover { border-color: var(--primaria); text-decoration: none; }
.cartao-praca h3 { margin: 0 0 .2rem; }
.metricas { display: flex; gap: .9rem; margin-top: .6rem; font-size: .9rem; flex-wrap: wrap; }

/* Avaliações */
.estrelas { display: inline-flex; gap: .1rem; }
.estrela { background: none; border: none; color: #cfd6de; font-size: 1.5rem; padding: 0 .1rem; line-height: 1; }
.estrela.ativa { color: #f9a825; }
.estrela:hover { background: none; color: #f9a825; }
.lista-avaliacoes { list-style: none; padding: 0; display: grid; gap: .5rem; }
.lista-avaliacoes li { background: var(--superficie); border-radius: var(--raio); padding: .6rem .9rem; box-shadow: var(--sombra); }
.lista-avaliacoes strong { color: #f9a825; letter-spacing: .05em; }

/* Linha do tempo */
.linha-tempo { list-style: none; padding: 0; margin: 0; border-left: 2px solid var(--borda); }
.linha-tempo li { position: relative; padding: 0 0 .8rem 1rem; }
.linha-tempo li::before { content: ''; position: absolute; left: -7px; top: .35rem; width: 10px; height: 10px; border-radius: 50%; background: var(--primaria); border: 2px solid #fff; }
.linha-tempo time { display: block; font-size: .78rem; color: var(--suave); }

/* Anexos */
.galeria { display: flex; gap: .5rem; flex-wrap: wrap; }
.galeria img { width: 120px; height: 90px; object-fit: cover; border-radius: 6px; border: 1px solid var(--borda); }

/* Alertas */
.alertas { list-style: none; padding: 0; display: grid; gap: .75rem; }
.alerta { background: var(--superficie); border-radius: var(--raio); padding: .8rem 1rem; box-shadow: var(--sombra); border-left: 5px solid var(--media); }
.alerta.grav-alta { border-left-color: var(--alta); }
.alerta.grav-critica { border-left-color: var(--critica); }
.alerta.novo { animation: piscar 1s ease-in-out 4; }
@keyframes piscar { 0%, 100% { background: var(--superficie); } 50% { background: #fff3e0; } }
.alerta-topo { display: flex; gap: .6rem; align-items: center; flex-wrap: wrap; }
.alerta-msg { margin: .4rem 0; font-size: 1.02rem; }
.alerta-rodape { display: flex; justify-content: space-between; align-items: center; gap: .5rem; flex-wrap: wrap; }
.lista-compacta { padding-left: 1rem; }
.lista-compacta li { margin-bottom: .3rem; }

/* Gráficos (CSS puro) */
.grafico-barras { display: flex; align-items: flex-end; gap: 2px; height: 160px; padding-top: 1rem; }
.barra { flex: 1; background: var(--primaria); border-radius: 3px 3px 0 0; min-height: 2px; position: relative; opacity: .85; }
.barra:hover { opacity: 1; }
.barra span { position: absolute; top: -1.1rem; left: 0; right: 0; text-align: center; font-size: .7rem; color: var(--suave); }
.eixo { display: flex; justify-content: space-between; font-size: .75rem; margin-top: .25rem; }
.barras-h { list-style: none; padding: 0; margin: 0 0 .5rem; display: grid; gap: .35rem; }
.barras-h li { display: grid; grid-template-columns: 140px 1fr 32px; gap: .5rem; align-items: center; font-size: .88rem; }
.barras-h-rotulo { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.barras-h-trilho { background: #eef1f5; border-radius: 4px; height: 12px; overflow: hidden; }
.barras-h-preenchimento { display: block; height: 100%; background: var(--primaria); border-radius: 4px; }
.barras-h-preenchimento.grav-baixa { background: var(--baixa); } .barras-h-preenchimento.grav-media { background: var(--media); }
.barras-h-preenchimento.grav-alta { background: var(--alta); } .barras-h-preenchimento.grav-critica { background: var(--critica); }
.barras-h-preenchimento.st-resolvida { background: var(--ok); } .barras-h-preenchimento.st-cancelada { background: #90a4ae; }
.barras-h-valor { text-align: right; font-weight: 600; }
```

### 1.6 Camada de API (tipos novos)

Substitua `src/api/pracas.ts` e `src/api/ocorrencias.ts` (ganham `detalhePraca`, tipos tipados e
`minhasOcorrencias` via RPC) e crie `src/api/avaliacoes.ts` e `src/api/anexos.ts`.

`src/api/pracas.ts`:

```ts
import { supabase } from '../lib/supabase';

export type PracaResumo = {
  id: string; nome: string; bairro: string; cidade: string;
  ocorrencias_abertas: number; alertas_novos: number; nota_media_seguranca: number | null;
};

export type DetalhePraca = {
  praca: {
    id: string; nome: string; descricao: string | null; logradouro: string; numero: string | null; bairro: string;
    cidade: string; uf: string; cep: string | null; latitude: number; longitude: number; area_m2: number | null;
    horario_abertura: string | null; horario_fechamento: string | null; ativa: boolean;
  };
  resumo: PracaResumo & { ocorrencias_30_dias: number; equipamentos: number; equipamentos_com_problema: number; qtd_avaliacoes: number };
  equipamentos: { id: string; tipo: string; codigo: string; descricao: string | null; localizacao: string | null; status: string }[];
  ocorrencias_abertas: { protocolo: string; titulo: string; categoria: string; gravidade: string; status: string; ocorrida_em: string }[];
  avaliacoes: { nota: number; comentario: string | null; criado_em: string; autor: string; minha: boolean | null }[];
};

export async function listarPracas(): Promise<PracaResumo[]> {
  const { data, error } = await supabase
    .from('vw_praca_resumo')
    .select('id, nome, bairro, cidade, ocorrencias_abertas, alertas_novos, nota_media_seguranca')
    .order('nome');
  if (error) throw error;
  return data;
}

/** Tela "Detalhe da praça" em uma chamada (RPC pública detalhe_praca). Retorna null se a praça não existe. */
export async function detalhePraca(id: string): Promise<DetalhePraca | null> {
  const { data, error } = await supabase.rpc('detalhe_praca', { p_praca_id: id });
  if (error) throw error;
  return (data as DetalhePraca | null) ?? null;
}

export async function listarCategorias() {
  const { data, error } = await supabase
    .from('categoria_ocorrencia').select('id, nome, gravidade_padrao').eq('ativa', true).order('nome');
  if (error) throw error;
  return data as { id: number; nome: string; gravidade_padrao: string }[];
}
```

`src/api/ocorrencias.ts`:

```ts
import { supabase } from '../lib/supabase';

export type Gravidade = 'BAIXA' | 'MEDIA' | 'ALTA' | 'CRITICA';

export type NovaOcorrencia = {
  praca_id: string; categoria_id: number; titulo: string; descricao: string;
  gravidade?: Gravidade; anonima?: boolean; latitude?: number; longitude?: number;
};

export type MinhaOcorrencia = {
  id: string; protocolo: string; titulo: string; descricao: string; status: string; gravidade: Gravidade;
  anonima: boolean; praca_id: string; categoria_id: number; ocorrida_em: string; criado_em: string; resolvida_em: string | null;
};

export type ProtocoloConsulta = {
  protocolo: string; titulo: string; status: string; gravidade: Gravidade; categoria: string; praca: string;
  ocorrida_em: string; resolvida_em: string | null;
  historico: { de: string | null; para: string; em: string; observacao: string | null }[];
};

export async function registrarOcorrencia(o: NovaOcorrencia) {
  const { data, error } = await supabase.rpc('registrar_ocorrencia', {
    p_praca_id: o.praca_id, p_categoria_id: o.categoria_id, p_titulo: o.titulo, p_descricao: o.descricao,
    p_gravidade: o.gravidade ?? null, p_anonima: o.anonima ?? false,
    p_latitude: o.latitude ?? null, p_longitude: o.longitude ?? null,
  });
  if (error) throw error;
  return data[0] as { id: string; protocolo: string; status: string };
}

/** Consulta pública pelo número do protocolo. Retorna null se não existir. */
export async function consultarProtocolo(protocolo: string): Promise<ProtocoloConsulta | null> {
  const { data, error } = await supabase.rpc('consultar_protocolo', { p_protocolo: protocolo.trim().toUpperCase() });
  if (error) throw error;
  return (data as ProtocoloConsulta | null) ?? null;
}

/** Ocorrências do usuário logado (RPC minhas_ocorrencias, mais recentes primeiro). */
export async function minhasOcorrencias(): Promise<MinhaOcorrencia[]> {
  const { data, error } = await supabase.rpc('minhas_ocorrencias');
  if (error) throw error;
  return data as MinhaOcorrencia[];
}
```

`src/api/avaliacoes.ts`:

```ts
import { supabase } from '../lib/supabase';

export type Avaliacao = { id: string; praca_id: string; usuario_id: string; nota: number; comentario: string | null; criado_em: string };

/** Nota 1..5 para a praça. Se o usuário já avaliou, a RPC atualiza a avaliação existente. */
export async function avaliarPraca(pracaId: string, nota: number, comentario?: string): Promise<Avaliacao> {
  const { data, error } = await supabase.rpc('avaliar_praca', {
    p_praca_id: pracaId, p_nota: nota, p_comentario: comentario?.trim() || null,
  });
  if (error) throw error;
  return (data as Avaliacao[])[0];
}
```

`src/api/anexos.ts`:

```ts
import { supabase } from '../lib/supabase';

export type Anexo = { id: string; ocorrencia_id: string; tipo: string; url: string; nome_arquivo: string | null; tamanho_bytes: number | null; enviado_em: string };

const BUCKET = 'anexos';
const TAMANHO_MAXIMO = 5 * 1024 * 1024; // 5 MB

function tipoMidia(arquivo: File): 'IMAGEM' | 'VIDEO' | 'AUDIO' | 'DOCUMENTO' {
  if (arquivo.type.startsWith('image/')) return 'IMAGEM';
  if (arquivo.type.startsWith('video/')) return 'VIDEO';
  if (arquivo.type.startsWith('audio/')) return 'AUDIO';
  return 'DOCUMENTO';
}

/**
 * 1) sobe o arquivo no bucket público "anexos" (pasta = id da ocorrência);
 * 2) registra o vínculo em anexo_ocorrencia via RPC registrar_anexo (só autor ou equipe).
 */
export async function anexarArquivo(ocorrenciaId: string, arquivo: File): Promise<Anexo> {
  if (arquivo.size > TAMANHO_MAXIMO) throw new Error(`Arquivo ${arquivo.name} excede 5 MB`);
  const seguro = arquivo.name.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^\w.-]+/g, '_');
  const caminho = `${ocorrenciaId}/${Date.now()}-${seguro}`;

  const { error: erroUpload } = await supabase.storage.from(BUCKET).upload(caminho, arquivo, { contentType: arquivo.type || undefined });
  if (erroUpload) throw erroUpload;

  const { data: { publicUrl } } = supabase.storage.from(BUCKET).getPublicUrl(caminho);

  const { data, error } = await supabase.rpc('registrar_anexo', {
    p_ocorrencia_id: ocorrenciaId, p_url: publicUrl, p_nome_arquivo: arquivo.name,
    p_tamanho_bytes: arquivo.size, p_tipo: tipoMidia(arquivo),
  });
  if (error) {
    await supabase.storage.from(BUCKET).remove([caminho]); // não deixa arquivo órfão
    throw error;
  }
  return (data as Anexo[])[0];
}

export async function listarAnexos(ocorrenciaId: string): Promise<Anexo[]> {
  const { data, error } = await supabase
    .from('anexo_ocorrencia').select('id, ocorrencia_id, tipo, url, nome_arquivo, tamanho_bytes, enviado_em')
    .eq('ocorrencia_id', ocorrenciaId).order('enviado_em');
  if (error) throw error;
  return data as Anexo[];
}
```

> `detalhe_praca`, `avaliar_praca` e `registrar_anexo` são RPCs novas que o **Davi** aplica na manhã de quarta.
> Até lá o build passa, mas as telas que as usam retornam erro "function not found". Normal.

### 1.7 Páginas que já existem: ajustes

`src/pages/Pracas.tsx` vira pública (sem logout, que agora fica no Layout), com busca e cartões:

```tsx
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { listarPracas, type PracaResumo } from '../api/pracas';
import { useAuth } from '../contexts/AuthContext';

export function Pracas() {
  const { session } = useAuth();
  const [pracas, setPracas] = useState<PracaResumo[] | null>(null);
  const [busca, setBusca] = useState('');
  const [erro, setErro] = useState<string | null>(null);

  useEffect(() => {
    listarPracas().then(setPracas).catch((e) => setErro(e.message));
  }, []);

  if (erro) return <p className="aviso erro">Erro ao carregar praças: {erro}</p>;
  if (!pracas) return <p className="aviso">Carregando...</p>;

  const termo = busca.trim().toLowerCase();
  const visiveis = termo ? pracas.filter((p) => `${p.nome} ${p.bairro}`.toLowerCase().includes(termo)) : pracas;

  return (
    <section>
      <div className="titulo-com-acoes">
        <h1>Praças monitoradas</h1>
        <input className="busca" placeholder="Buscar por nome ou bairro" value={busca} onChange={(e) => setBusca(e.target.value)} />
      </div>
      <p className="suave">
        Veja a situação de cada praça. {session ? <Link to="/ocorrencias/nova">Registre uma ocorrência</Link> : <><Link to="/login">Entre</Link> para registrar ocorrências e avaliar</>}.
        {' '}Sem login você pode <Link to="/protocolo">consultar um protocolo</Link>.
      </p>
      <div className="grade-pracas">
        {visiveis.map((p) => (
          <Link key={p.id} to={`/pracas/${p.id}`} className="cartao-praca">
            <h3>{p.nome}</h3>
            <div className="suave">{p.bairro} · {p.cidade}</div>
            <div className="metricas">
              <span title="Ocorrências em aberto">⚠ {p.ocorrencias_abertas} abertas</span>
              <span title="Alertas novos" className={p.alertas_novos > 0 ? 'perigo-texto' : ''}>🔔 {p.alertas_novos} alertas</span>
              <span title="Sensação de segurança (1 a 5)">★ {p.nota_media_seguranca != null ? Number(p.nota_media_seguranca).toFixed(1) : '—'}</span>
            </div>
          </Link>
        ))}
      </div>
      {visiveis.length === 0 && <p className="aviso">Nenhuma praça encontrada.</p>}
    </section>
  );
}
```

`src/pages/Login.tsx` redireciona por perfil (agente → painel, gestor → dashboard) e volta para a página que
pediu login:

```tsx
import { useState } from 'react';
import { useNavigate, Link, useLocation } from 'react-router-dom';
import { entrar } from '../api/auth';
import { supabase } from '../lib/supabase';

/** Depois do login, cada perfil cai na sua tela principal. */
async function destinoPorPerfil(userId: string, de?: string) {
  if (de && de !== '/login') return de;
  const { data } = await supabase.from('usuario').select('perfil').eq('id', userId).single();
  switch (data?.perfil) {
    case 'AGENTE': return '/painel';
    case 'GESTOR':
    case 'ADMIN': return '/dashboard';
    default: return '/pracas';
  }
}

export function Login() {
  const [email, setEmail] = useState('');
  const [senha, setSenha] = useState('');
  const [erro, setErro] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);
  const navigate = useNavigate();
  const location = useLocation();
  const de = (location.state as { de?: string } | null)?.de;

  async function enviar(e: React.FormEvent) {
    e.preventDefault();
    setErro(null); setEnviando(true);
    try {
      const session = await entrar(email, senha);
      navigate(await destinoPorPerfil(session!.user.id, de), { replace: true });
    } catch (err) {
      const m = (err as Error).message;
      setErro(m === 'Invalid login credentials' ? 'E-mail ou senha inválidos.' : m);
    } finally {
      setEnviando(false);
    }
  }

  return (
    <form onSubmit={enviar} className="estreito formulario">
      <h1>Entrar</h1>
      <label>E-mail<input type="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} required /></label>
      <label>Senha<input type="password" autoComplete="current-password" value={senha} onChange={(e) => setSenha(e.target.value)} required /></label>
      <div className="acoes">
        <button type="submit" disabled={enviando}>{enviando ? 'Entrando...' : 'Entrar'}</button>
        <Link to="/cadastro">Criar conta</Link>
      </div>
      {erro && <p className="aviso erro">{erro}</p>}
      <p className="suave">Só quer acompanhar uma ocorrência? <Link to="/protocolo">Consulte pelo protocolo</Link>, sem login.</p>
    </form>
  );
}
```

Em `src/pages/Cadastro.tsx`, só troque o `catch (err: any)` por `catch (err)` com
`setErro((err as Error).message)` — o lint reprova `any`.

### 1.8 Verificar e abrir o PR da base

```bash
npm run lint && npm run build && npm run dev
```

No navegador: `/pracas` abre sem login; `/painel` sem login redireciona para `/login`; logado como
`cidadao.demo@safetech.app` o menu mostra "Minhas ocorrências" (404 por enquanto, normal) e `/painel`
mostra "Seu perfil (CIDADAO) não tem acesso"; logado como `agente.demo` o menu mostra Painel e Alertas.

```bash
git add -A && git commit -m "feat(front): base do MVP - contexto de auth com perfil, layout, rotas protegidas e estilo"
git push -u origin feat/cp3-santhiago
```

Abra o PR, marque Davi como revisor e avise no grupo: **"base do front em main, podem puxar"**.
Depois do merge, continue na mesma branch (`git pull origin main` antes).

## Passo 2 — Detalhe da praça + avaliação (tarde de quarta)

Crie `src/pages/DetalhePraca.tsx`. Uma única RPC (`detalhe_praca`) traz praça, resumo, equipamentos,
ocorrências abertas e últimas avaliações. A avaliação usa estrelas e a RPC `avaliar_praca` (atualiza se já avaliou).

```tsx
import { useCallback, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { detalhePraca, type DetalhePraca as Detalhe } from '../api/pracas';
import { avaliarPraca } from '../api/avaliacoes';
import { useAuth } from '../contexts/AuthContext';

const ROTULO_EQUIP: Record<string, string> = {
  CAMERA: 'Câmera', ILUMINACAO: 'Iluminação', BOTAO_PANICO: 'Botão de pânico', TOTEM: 'Totem', SENSOR: 'Sensor',
};

export function DetalhePraca() {
  const { id = '' } = useParams();
  const { session, usuario } = useAuth();
  const [dados, setDados] = useState<Detalhe | null | undefined>(undefined); // undefined = carregando
  const [erro, setErro] = useState<string | null>(null);
  const [nota, setNota] = useState(0);
  const [comentario, setComentario] = useState('');
  const [enviando, setEnviando] = useState(false);

  const carregar = useCallback(() => {
    detalhePraca(id).then(setDados).catch((e) => setErro(e.message));
  }, [id]);

  useEffect(() => { carregar(); }, [carregar]);

  async function enviarAvaliacao(e: React.FormEvent) {
    e.preventDefault();
    if (!nota) { setErro('Escolha uma nota de 1 a 5'); return; }
    setEnviando(true); setErro(null);
    try {
      await avaliarPraca(id, nota, comentario);
      setComentario(''); setNota(0);
      carregar();
    } catch (err) {
      setErro((err as Error).message);
    } finally {
      setEnviando(false);
    }
  }

  if (erro && !dados) return <p className="aviso erro">Erro: {erro}</p>;
  if (dados === undefined) return <p className="aviso">Carregando...</p>;
  if (dados === null) return <p className="aviso">Praça não encontrada. <Link to="/pracas">Voltar</Link></p>;

  const { praca, resumo, equipamentos, ocorrencias_abertas, avaliacoes } = dados;
  const minha = avaliacoes.find((a) => a.minha);
  const mapa = `https://www.openstreetmap.org/?mlat=${praca.latitude}&mlon=${praca.longitude}#map=17/${praca.latitude}/${praca.longitude}`;

  return (
    <section>
      <p><Link to="/pracas">← Praças</Link></p>
      <h1>{praca.nome}</h1>
      <p className="suave">
        {praca.logradouro}{praca.numero ? `, ${praca.numero}` : ''} · {praca.bairro}, {praca.cidade}/{praca.uf}
        {praca.horario_abertura && ` · ${praca.horario_abertura.slice(0, 5)} às ${praca.horario_fechamento?.slice(0, 5)}`}
        {' · '}<a href={mapa} target="_blank" rel="noreferrer">ver no mapa</a>
      </p>
      {praca.descricao && <p>{praca.descricao}</p>}

      <div className="cartoes">
        <Indicador rotulo="Ocorrências abertas" valor={resumo.ocorrencias_abertas} />
        <Indicador rotulo="Últimos 30 dias" valor={resumo.ocorrencias_30_dias} />
        <Indicador rotulo="Alertas novos" valor={resumo.alertas_novos} destaque={resumo.alertas_novos > 0} />
        <Indicador rotulo="Equipamentos c/ problema" valor={`${resumo.equipamentos_com_problema}/${resumo.equipamentos}`} />
        <Indicador rotulo="Sensação de segurança" valor={resumo.nota_media_seguranca ? `${Number(resumo.nota_media_seguranca).toFixed(1)} / 5` : '—'} sub={`${resumo.qtd_avaliacoes} avaliações`} />
      </div>

      <p>
        <Link className="botao" to={`/ocorrencias/nova?praca=${praca.id}`}>Registrar ocorrência nesta praça</Link>
      </p>

      <h2>Equipamentos de segurança</h2>
      {equipamentos.length === 0 ? <p className="suave">Nenhum equipamento cadastrado.</p> : (
        <table>
          <thead><tr><th>Tipo</th><th>Código</th><th>Local</th><th>Status</th></tr></thead>
          <tbody>
            {equipamentos.map((e) => (
              <tr key={e.id}>
                <td>{ROTULO_EQUIP[e.tipo] ?? e.tipo}</td><td>{e.codigo}</td><td>{e.localizacao ?? '—'}</td>
                <td><span className={`tag tag-${e.status.toLowerCase()}`}>{e.status.replace('_', ' ')}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <h2>Ocorrências em aberto</h2>
      {ocorrencias_abertas.length === 0 ? <p className="suave">Nenhuma ocorrência em aberto. 🎉</p> : (
        <table>
          <thead><tr><th>Protocolo</th><th>Título</th><th>Categoria</th><th>Gravidade</th><th>Status</th><th>Quando</th></tr></thead>
          <tbody>
            {ocorrencias_abertas.map((o) => (
              <tr key={o.protocolo}>
                <td><Link to={`/protocolo?p=${o.protocolo}`}>{o.protocolo}</Link></td><td>{o.titulo}</td><td>{o.categoria}</td>
                <td><span className={`tag tag-${o.gravidade.toLowerCase()}`}>{o.gravidade}</span></td>
                <td>{o.status.replace('_', ' ')}</td><td>{new Date(o.ocorrida_em).toLocaleString('pt-BR')}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <h2>Como as pessoas se sentem aqui</h2>
      {session && usuario ? (
        <form onSubmit={enviarAvaliacao} className="formulario-inline">
          <span>{minha ? `Sua nota atual: ${minha.nota}. Alterar:` : 'Sua avaliação:'}</span>
          <div className="estrelas" role="radiogroup" aria-label="Nota de 1 a 5">
            {[1, 2, 3, 4, 5].map((n) => (
              <button type="button" key={n} className={n <= nota ? 'estrela ativa' : 'estrela'} onClick={() => setNota(n)} aria-label={`${n} de 5`}>★</button>
            ))}
          </div>
          <input placeholder="Comentário (opcional)" maxLength={500} value={comentario} onChange={(e) => setComentario(e.target.value)} />
          <button type="submit" disabled={enviando}>{enviando ? 'Enviando...' : 'Avaliar'}</button>
        </form>
      ) : (
        <p className="suave"><Link to="/login">Entre</Link> para avaliar a sensação de segurança desta praça.</p>
      )}
      {erro && <p className="aviso erro">{erro}</p>}
      <ul className="lista-avaliacoes">
        {avaliacoes.map((a, i) => (
          <li key={i}>
            <strong>{'★'.repeat(a.nota)}{'☆'.repeat(5 - a.nota)}</strong> {a.autor}{a.minha ? ' (você)' : ''}
            <span className="suave"> · {new Date(a.criado_em).toLocaleDateString('pt-BR')}</span>
            {a.comentario && <div>{a.comentario}</div>}
          </li>
        ))}
      </ul>
    </section>
  );
}

function Indicador({ rotulo, valor, sub, destaque }: { rotulo: string; valor: number | string; sub?: string; destaque?: boolean }) {
  return (
    <div className={destaque ? 'cartao destaque' : 'cartao'}>
      <div className="cartao-valor">{valor}</div>
      <div className="cartao-rotulo">{rotulo}</div>
      {sub && <div className="suave">{sub}</div>}
    </div>
  );
}
```

Teste: `/pracas/aaaaaaaa-0000-0000-0000-000000000001` sem login mostra tudo e pede login para avaliar; logado
como cidadão, avalie com 4 estrelas, recarregue e veja "Sua nota atual: 4"; avalie de novo com 2 e confira
que não duplicou na lista.

## Passo 3 — Nova ocorrência com anexo, Minhas ocorrências, Protocolo (quinta)

### 3.1 Nova ocorrência com até 3 fotos/vídeos

Substitua `src/pages/NovaOcorrencia.tsx`. O fluxo é: registra a ocorrência (RPC) → para cada arquivo, sobe no
bucket `anexos` e registra via `registrar_anexo`. Falha em anexo não perde a ocorrência.

```tsx
import { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { listarPracas, listarCategorias, type PracaResumo } from '../api/pracas';
import { registrarOcorrencia, type Gravidade } from '../api/ocorrencias';
import { anexarArquivo } from '../api/anexos';

const MAX_ARQUIVOS = 3;

export function NovaOcorrencia() {
  const [params] = useSearchParams();
  const [pracas, setPracas] = useState<PracaResumo[]>([]);
  const [categorias, setCategorias] = useState<{ id: number; nome: string; gravidade_padrao: string }[]>([]);
  const [pracaId, setPracaId] = useState(params.get('praca') ?? '');
  const [categoriaId, setCategoriaId] = useState('');
  const [titulo, setTitulo] = useState('');
  const [descricao, setDescricao] = useState('');
  const [gravidade, setGravidade] = useState<Gravidade | ''>('');
  const [anonima, setAnonima] = useState(false);
  const [arquivos, setArquivos] = useState<File[]>([]);
  const [erro, setErro] = useState<string | null>(null);
  const [etapa, setEtapa] = useState<'form' | 'enviando' | 'anexando' | 'ok'>('form');
  const [resultado, setResultado] = useState<{ protocolo: string; anexos: number; falhas: string[] } | null>(null);

  useEffect(() => {
    listarPracas().then(setPracas).catch((e) => setErro(e.message));
    listarCategorias().then(setCategorias).catch((e) => setErro(e.message));
  }, []);

  function escolherArquivos(e: React.ChangeEvent<HTMLInputElement>) {
    const lista = Array.from(e.target.files ?? []).slice(0, MAX_ARQUIVOS);
    setArquivos(lista);
  }

  async function enviar(e: React.FormEvent) {
    e.preventDefault();
    setErro(null); setEtapa('enviando');
    try {
      const r = await registrarOcorrencia({
        praca_id: pracaId, categoria_id: Number(categoriaId), titulo, descricao,
        gravidade: gravidade || undefined, anonima,
      });
      // Anexos: um por vez, erros não derrubam a ocorrência já registrada
      const falhas: string[] = [];
      let ok = 0;
      if (arquivos.length) {
        setEtapa('anexando');
        for (const a of arquivos) {
          try { await anexarArquivo(r.id, a); ok++; }
          catch (err) { falhas.push(`${a.name}: ${(err as Error).message}`); }
        }
      }
      setResultado({ protocolo: r.protocolo, anexos: ok, falhas });
      setEtapa('ok');
    } catch (err) {
      setErro((err as Error).message);
      setEtapa('form');
    }
  }

  if (etapa === 'ok' && resultado) {
    return (
      <section className="estreito">
        <h1>Ocorrência registrada!</h1>
        <p>Guarde o protocolo para acompanhar: <strong className="protocolo">{resultado.protocolo}</strong></p>
        {resultado.anexos > 0 && <p>{resultado.anexos} anexo(s) enviado(s).</p>}
        {resultado.falhas.length > 0 && (
          <div className="aviso erro">Alguns anexos falharam:<ul>{resultado.falhas.map((f) => <li key={f}>{f}</li>)}</ul></div>
        )}
        <p>
          <Link className="botao" to={`/protocolo?p=${resultado.protocolo}`}>Acompanhar</Link>{' '}
          <Link to="/minhas-ocorrencias">Minhas ocorrências</Link> · <Link to="/pracas">Praças</Link>
        </p>
      </section>
    );
  }

  const categoria = categorias.find((c) => String(c.id) === categoriaId);

  return (
    <form onSubmit={enviar} className="estreito formulario">
      <h1>Nova ocorrência</h1>
      <label>Praça
        <select value={pracaId} onChange={(e) => setPracaId(e.target.value)} required>
          <option value="">Selecione a praça</option>
          {pracas.map((p) => <option key={p.id} value={p.id}>{p.nome} · {p.bairro}</option>)}
        </select>
      </label>
      <label>Categoria
        <select value={categoriaId} onChange={(e) => setCategoriaId(e.target.value)} required>
          <option value="">Selecione a categoria</option>
          {categorias.map((c) => <option key={c.id} value={c.id}>{c.nome}</option>)}
        </select>
      </label>
      <label>Título
        <input placeholder="Resumo em uma frase" maxLength={150} value={titulo} onChange={(e) => setTitulo(e.target.value)} required />
      </label>
      <label>Descrição
        <textarea placeholder="O que aconteceu, onde na praça, quando" rows={4} value={descricao} onChange={(e) => setDescricao(e.target.value)} required />
      </label>
      <label>Gravidade
        <select value={gravidade} onChange={(e) => setGravidade(e.target.value as Gravidade | '')}>
          <option value="">{categoria ? `Padrão da categoria (${categoria.gravidade_padrao})` : 'Padrão da categoria'}</option>
          <option value="BAIXA">Baixa</option>
          <option value="MEDIA">Média</option>
          <option value="ALTA">Alta</option>
          <option value="CRITICA">Crítica</option>
        </select>
      </label>
      <label>Fotos ou vídeos (até {MAX_ARQUIVOS}, 5 MB cada)
        <input type="file" accept="image/*,video/*" multiple onChange={escolherArquivos} />
      </label>
      {arquivos.length > 0 && <ul className="suave">{arquivos.map((a) => <li key={a.name}>{a.name} ({Math.round(a.size / 1024)} KB)</li>)}</ul>}
      <label className="linha">
        <input type="checkbox" checked={anonima} onChange={(e) => setAnonima(e.target.checked)} />
        Registrar como anônima (seu nome não aparece para a equipe)
      </label>
      <div className="acoes">
        <button type="submit" disabled={etapa !== 'form'}>
          {etapa === 'enviando' ? 'Registrando...' : etapa === 'anexando' ? 'Enviando anexos...' : 'Registrar ocorrência'}
        </button>
        <Link to="/pracas">Cancelar</Link>
      </div>
      {erro && <p className="aviso erro">{erro}</p>}
    </form>
  );
}
```

### 3.2 Minhas ocorrências

Crie `src/pages/MinhasOcorrencias.tsx` (RPC `minhas_ocorrencias` do Davi no CP2 + galeria de anexos):

```tsx
import { Fragment, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { minhasOcorrencias, type MinhaOcorrencia } from '../api/ocorrencias';
import { listarAnexos, type Anexo } from '../api/anexos';

export function MinhasOcorrencias() {
  const [lista, setLista] = useState<MinhaOcorrencia[] | null>(null);
  const [erro, setErro] = useState<string | null>(null);
  const [aberta, setAberta] = useState<string | null>(null);
  const [anexos, setAnexos] = useState<Record<string, Anexo[]>>({});

  useEffect(() => {
    minhasOcorrencias().then(setLista).catch((e) => setErro(e.message));
  }, []);

  async function alternar(id: string) {
    if (aberta === id) { setAberta(null); return; }
    setAberta(id);
    if (!anexos[id]) {
      try {
        const lst = await listarAnexos(id);
        setAnexos((a) => ({ ...a, [id]: lst }));
      } catch (e) {
        setErro((e as Error).message);
      }
    }
  }

  if (erro) return <p className="aviso erro">Erro: {erro}</p>;
  if (!lista) return <p className="aviso">Carregando...</p>;

  return (
    <section>
      <h1>Minhas ocorrências</h1>
      <p><Link className="botao" to="/ocorrencias/nova">Registrar nova ocorrência</Link></p>
      {lista.length === 0 ? <p className="suave">Você ainda não registrou ocorrências.</p> : (
        <table>
          <thead><tr><th>Protocolo</th><th>Título</th><th>Gravidade</th><th>Status</th><th>Quando</th><th></th></tr></thead>
          <tbody>
            {lista.map((o) => (
              <Fragment key={o.id}>
                <tr>
                  <td><Link to={`/protocolo?p=${o.protocolo}`}>{o.protocolo}</Link></td>
                  <td>{o.titulo}{o.anonima && <small className="tag"> anônima</small>}</td>
                  <td><span className={`tag tag-${o.gravidade.toLowerCase()}`}>{o.gravidade}</span></td>
                  <td>{o.status.replace('_', ' ')}</td>
                  <td>{new Date(o.ocorrida_em).toLocaleString('pt-BR')}</td>
                  <td><button className="link" onClick={() => alternar(o.id)}>{aberta === o.id ? 'fechar' : 'detalhes'}</button></td>
                </tr>
                {aberta === o.id && (
                  <tr className="detalhe">
                    <td colSpan={6}>
                      <p>{o.descricao}</p>
                      {!anexos[o.id] ? <p className="suave">Carregando anexos...</p>
                        : anexos[o.id].length === 0 ? <p className="suave">Sem anexos.</p>
                        : (
                          <div className="galeria">
                            {anexos[o.id].map((a) => (
                              a.tipo === 'IMAGEM'
                                ? <a key={a.id} href={a.url} target="_blank" rel="noreferrer"><img src={a.url} alt={a.nome_arquivo ?? 'anexo'} /></a>
                                : <a key={a.id} href={a.url} target="_blank" rel="noreferrer">{a.nome_arquivo ?? a.url}</a>
                            ))}
                          </div>
                        )}
                    </td>
                  </tr>
                )}
              </Fragment>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}
```

### 3.3 Protocolo com linha do tempo e link direto

Substitua `src/pages/Protocolo.tsx`. Agora aceita `/protocolo?p=STC-2026-000001` (os links do app apontam
para cá) e mostra o histórico como linha do tempo em vez de JSON cru:

```tsx
import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { consultarProtocolo, type ProtocoloConsulta } from '../api/ocorrencias';

export function Protocolo() {
  const [params, setParams] = useSearchParams();
  const [protocolo, setProtocolo] = useState(params.get('p') ?? '');
  const [resultado, setResultado] = useState<ProtocoloConsulta | null | undefined>(undefined);
  const [erro, setErro] = useState<string | null>(null);

  // A busca é disparada pela URL (/protocolo?p=STC-2026-000001), o que permite link direto e botão "voltar".
  useEffect(() => {
    const p = params.get('p');
    if (!p) return;
    consultarProtocolo(p).then(setResultado).catch((err: Error) => setErro(err.message));
  }, [params]);

  function consultar(e: React.FormEvent) {
    e.preventDefault();
    setErro(null); setResultado(undefined);
    setParams({ p: protocolo.trim().toUpperCase() });
  }

  return (
    <section className="estreito">
      <h1>Consultar protocolo</h1>
      <p className="suave">Acompanhe sua ocorrência sem precisar de login. Formato: STC-AAAA-NNNNNN.</p>
      <form onSubmit={consultar} className="formulario-inline">
        <input placeholder="STC-2026-000001" value={protocolo} onChange={(e) => setProtocolo(e.target.value)} required />
        <button type="submit">Consultar</button>
      </form>
      {erro && <p className="aviso erro">{erro}</p>}
      {resultado === null && <p className="aviso">Protocolo não encontrado.</p>}
      {resultado && (
        <article className="cartao-largo">
          <h2>{resultado.titulo} <span className={`tag tag-${resultado.gravidade.toLowerCase()}`}>{resultado.gravidade}</span></h2>
          <p><strong>{resultado.protocolo}</strong> · {resultado.praca} · {resultado.categoria}</p>
          <p>Status atual: <strong>{resultado.status.replace('_', ' ')}</strong>
            {resultado.resolvida_em && <> · resolvida em {new Date(resultado.resolvida_em).toLocaleString('pt-BR')}</>}</p>
          <h3>Linha do tempo</h3>
          <ol className="linha-tempo">
            {resultado.historico.map((h, i) => (
              <li key={i}>
                <time>{new Date(h.em).toLocaleString('pt-BR')}</time>
                <div>{h.de ? `${h.de.replace('_', ' ')} → ` : ''}<strong>{h.para.replace('_', ' ')}</strong>{h.observacao && <div className="suave">{h.observacao}</div>}</div>
              </li>
            ))}
          </ol>
        </article>
      )}
    </section>
  );
}
```

### 3.4 Teste ponta a ponta do cidadão

1. Cadastre um usuário novo pelo app → cai em `/pracas` logado, nome no topo com tag CIDADAO.
2. Abra uma praça → "Registrar ocorrência nesta praça" → preencha, anexe 1 foto → protocolo na tela.
3. "Acompanhar" → linha do tempo com "ABERTA". Copie a URL: tem `?p=STC-...`.
4. Menu "Minhas ocorrências" → a ocorrência aparece → "detalhes" mostra a foto.
5. Peça ao Davi para assumir e resolver pelo painel dele → recarregue o protocolo: 3 passos na linha do tempo.

```bash
npm run lint && npm run build
git add -A && git commit -m "feat(front): detalhe da praca, avaliacao, anexos, minhas ocorrencias e protocolo"
git push
```

Abra o PR. Evidências (prints das 5 etapas) em `docs/checkpoint-2/../checkpoint-3/evidencias/santhiago-front.md`.

## Passo 4 — Sexta: correções e ensaio

Pegue as issues de bug que o QA abriu com a etiqueta `front`, corrija, PR. Ensaie a parte do cidadão da demo
(2 min): cadastro → praça → ocorrência com foto → protocolo.

## Erros comuns

| Sintoma | Causa / solução |
|---------|-----------------|
| `useAuth precisa estar dentro de <AuthProvider>` | `AuthProvider` tem que envolver o `BrowserRouter` em `App.tsx` (já está no arquivo acima). |
| Tela pisca "Carregando..." e volta para `/login` ao recarregar | Normal por um instante; se ficar, confira se `onAuthStateChange` está no `AuthContext` e se o `.env` tem a anon key certa. |
| `Could not find the function safetech.detalhe_praca` | Davi ainda não aplicou `09_rpc_cp3.sql`. |
| Upload dá `new row violates row-level security policy` | Precisa estar logado; o bucket só aceita upload de `authenticated`. |
| Imagem do anexo não abre (`Bucket not found`) | Bucket `anexos` não está público. Lucas confere no painel. |
| Lint reclama `set-state-in-effect` | Não chame `setX()` direto no corpo do `useEffect`; chame dentro do `.then()` da requisição, como nos arquivos acima. |
| Rota `/pracas/:id` dá 404 na Vercel ao recarregar | Falta o `vercel.json` com rewrite (Lucas). Em dev local não acontece. |

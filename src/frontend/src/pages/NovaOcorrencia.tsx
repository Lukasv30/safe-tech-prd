import { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { listarPracas, listarCategorias, type PracaResumo } from '../api/pracas';
import { registrarOcorrencia } from '../api/ocorrencias';

type Gravidade = 'BAIXA' | 'MEDIA' | 'ALTA' | 'CRITICA';

export function NovaOcorrencia() {
  const [params] = useSearchParams();
  const [pracas, setPracas] = useState<PracaResumo[]>([]);
  const [categorias, setCategorias] = useState<{ id: number; nome: string }[]>([]);
  const [pracaId, setPracaId] = useState(params.get('praca') ?? '');
  const [categoriaId, setCategoriaId] = useState('');
  const [titulo, setTitulo] = useState('');
  const [descricao, setDescricao] = useState('');
  const [gravidade, setGravidade] = useState<Gravidade | ''>('');
  const [anonima, setAnonima] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [protocolo, setProtocolo] = useState<string | null>(null);

  useEffect(() => {
    listarPracas().then(setPracas).catch((e) => setErro(e.message));
    listarCategorias().then(setCategorias).catch((e) => setErro(e.message));
  }, []);

  async function enviar(e: React.FormEvent) {
    e.preventDefault();
    setErro(null);
    try {
      const r = await registrarOcorrencia({
        praca_id: pracaId, categoria_id: Number(categoriaId), titulo, descricao,
        gravidade: gravidade || undefined, anonima,
      });
      setProtocolo(r.protocolo);
    } catch (err: any) {
      setErro(err.message);
    }
  }

  if (protocolo) {
    return (
      <div>
        <h1>Ocorrência registrada!</h1>
        <p>Seu protocolo: <strong>{protocolo}</strong></p>
        <p><Link to="/protocolo">Consultar protocolo</Link> | <Link to="/pracas">Voltar às praças</Link></p>
      </div>
    );
  }

  return (
    <form onSubmit={enviar}>
      <h1>Nova ocorrência</h1>
      <div>
        <select value={pracaId} onChange={(e) => setPracaId(e.target.value)} required>
          <option value="">Selecione a praça</option>
          {pracas.map((p) => <option key={p.id} value={p.id}>{p.nome}</option>)}
        </select>
      </div>
      <div>
        <select value={categoriaId} onChange={(e) => setCategoriaId(e.target.value)} required>
          <option value="">Selecione a categoria</option>
          {categorias.map((c) => <option key={c.id} value={c.id}>{c.nome}</option>)}
        </select>
      </div>
      <div><input placeholder="Título" value={titulo} onChange={(e) => setTitulo(e.target.value)} required /></div>
      <div><textarea placeholder="Descrição" value={descricao} onChange={(e) => setDescricao(e.target.value)} required /></div>
      <div>
        <select value={gravidade} onChange={(e) => setGravidade(e.target.value as Gravidade | '')}>
          <option value="">Gravidade (padrão da categoria)</option>
          <option value="BAIXA">Baixa</option>
          <option value="MEDIA">Média</option>
          <option value="ALTA">Alta</option>
          <option value="CRITICA">Crítica</option>
        </select>
      </div>
      <label><input type="checkbox" checked={anonima} onChange={(e) => setAnonima(e.target.checked)} /> Anônima</label>
      <div><button type="submit">Registrar</button></div>
      {erro && <p>{erro}</p>}
      <p><Link to="/pracas">Voltar</Link></p>
    </form>
  );
}
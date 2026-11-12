import { useState } from 'react';
import { Link } from 'react-router-dom';
import { consultarProtocolo } from '../api/ocorrencias';

function Valor({ v }: { v: unknown }) {
  if (v === null || v === undefined) return <>-</>;
  if (Array.isArray(v)) {
    return (
      <ul>
        {v.map((item, i) => <li key={i}><Valor v={item} /></li>)}
      </ul>
    );
  }
  if (typeof v === 'object') {
    return (
      <ul>
        {Object.entries(v as Record<string, unknown>).map(([k, val]) => (
          <li key={k}><strong>{k}:</strong> <Valor v={val} /></li>
        ))}
      </ul>
    );
  }
  return <>{String(v)}</>;
}

export function Protocolo() {
  const [protocolo, setProtocolo] = useState('');
  const [resultado, setResultado] = useState<unknown>(undefined);
  const [erro, setErro] = useState<string | null>(null);

  async function consultar(e: React.FormEvent) {
    e.preventDefault();
    setErro(null);
    setResultado(undefined);
    try {
      setResultado(await consultarProtocolo(protocolo.trim()));
    } catch (err: any) {
      setErro(err.message);
    }
  }

  return (
    <div>
      <h1>Consultar protocolo</h1>
      <form onSubmit={consultar}>
        <input placeholder="Número do protocolo" value={protocolo} onChange={(e) => setProtocolo(e.target.value)} required />
        <button type="submit">Consultar</button>
      </form>
      {erro && <p>{erro}</p>}
      {resultado === null && <p>Protocolo não encontrado.</p>}
      {resultado !== undefined && resultado !== null && <Valor v={resultado} />}
      <p><Link to="/login">Login</Link> | <Link to="/pracas">Praças</Link></p>
    </div>
  );
}
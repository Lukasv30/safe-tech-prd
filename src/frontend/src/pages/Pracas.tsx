import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { listarPracas, type PracaResumo } from '../api/pracas';
import { sair } from '../api/auth';

export function Pracas() {
  const [pracas, setPracas] = useState<PracaResumo[]>([]);
  const [erro, setErro] = useState<string | null>(null);
  const navigate = useNavigate();

  useEffect(() => {
    listarPracas().then(setPracas).catch((e) => setErro(e.message));
  }, []);

  async function logout() {
    await sair();
    navigate('/login');
  }

  if (erro) return <p>Erro ao carregar praças: {erro}</p>;
  return (
    <div>
      <h1>Praças</h1>
      <p>
        <Link to="/ocorrencias/nova">Registrar ocorrência</Link> | <Link to="/protocolo">Consultar protocolo</Link> |{' '}
        <button onClick={logout}>Sair</button>
      </p>
      <table>
        <thead><tr><th>Praça</th><th>Bairro</th><th>Abertas</th><th>Alertas</th><th>Nota</th><th></th></tr></thead>
        <tbody>
          {pracas.map((p) => (
            <tr key={p.id}>
              <td>{p.nome}</td><td>{p.bairro}</td><td>{p.ocorrencias_abertas}</td>
              <td>{p.alertas_novos}</td><td>{p.nota_media_seguranca ?? '-'}</td>
              <td><Link to={`/ocorrencias/nova?praca=${p.id}`}>Registrar ocorrência</Link></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
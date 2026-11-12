import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { entrar } from '../api/auth';

export function Login() {
  const [email, setEmail] = useState('');
  const [senha, setSenha] = useState('');
  const [erro, setErro] = useState<string | null>(null);
  const navigate = useNavigate();

  async function enviar(e: React.FormEvent) {
    e.preventDefault();
    try {
      await entrar(email, senha);
      navigate('/pracas');
    } catch (err: any) {
      setErro(err.message);
    }
  }

  return (
    <form onSubmit={enviar}>
      <h1>Login</h1>
      <div><input placeholder="E-mail" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required /></div>
      <div><input placeholder="Senha" type="password" value={senha} onChange={(e) => setSenha(e.target.value)} required /></div>
      <button type="submit">Entrar</button>
      {erro && <p>{erro}</p>}
      <p>Não tem conta? <Link to="/cadastro">Cadastre-se</Link></p>
      <p><Link to="/protocolo">Consultar protocolo</Link></p>
    </form>
  );
}
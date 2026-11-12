import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { cadastrar } from '../api/auth';

export function Cadastro() {
  const [nome, setNome] = useState('');
  const [email, setEmail] = useState('');
  const [telefone, setTelefone] = useState('');
  const [senha, setSenha] = useState('');
  const [erro, setErro] = useState<string | null>(null);
  const navigate = useNavigate();

  async function enviar(e: React.FormEvent) {
    e.preventDefault();
    try {
      await cadastrar(nome, email, senha, telefone || undefined);
      navigate('/pracas');
    } catch (err: any) {
      setErro(err.message);
    }
  }

  return (
    <form onSubmit={enviar}>
      <h1>Cadastro</h1>
      <div><input placeholder="Nome" value={nome} onChange={(e) => setNome(e.target.value)} required /></div>
      <div><input placeholder="E-mail" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required /></div>
      <div><input placeholder="Telefone" value={telefone} onChange={(e) => setTelefone(e.target.value)} /></div>
      <div><input placeholder="Senha" type="password" minLength={6} value={senha} onChange={(e) => setSenha(e.target.value)} required /></div>
      <button type="submit">Cadastrar</button>
      {erro && <p>{erro}</p>}
      <p>Já tem conta? <Link to="/login">Entrar</Link></p>
    </form>
  );
}
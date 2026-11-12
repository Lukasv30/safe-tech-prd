import { useEffect, useState, type ReactNode } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { supabase } from './lib/supabase';
import { Login } from './pages/Login';
import { Cadastro } from './pages/Cadastro';
import { Pracas } from './pages/Pracas';
import { NovaOcorrencia } from './pages/NovaOcorrencia';
import { Protocolo } from './pages/Protocolo';

function Protegida({ children }: { children: ReactNode }) {
  const [estado, setEstado] = useState<'carregando' | 'logado' | 'deslogado'>('carregando');

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setEstado(data.session ? 'logado' : 'deslogado'));
  }, []);

  if (estado === 'carregando') return <p>Carregando...</p>;
  if (estado === 'deslogado') return <Navigate to="/login" replace />;
  return <>{children}</>;
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/cadastro" element={<Cadastro />} />
        <Route path="/protocolo" element={<Protocolo />} />
        <Route path="/pracas" element={<Protegida><Pracas /></Protegida>} />
        <Route path="/ocorrencias/nova" element={<Protegida><NovaOcorrencia /></Protegida>} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
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
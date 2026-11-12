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
  return data;
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
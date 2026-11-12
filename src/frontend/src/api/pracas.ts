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
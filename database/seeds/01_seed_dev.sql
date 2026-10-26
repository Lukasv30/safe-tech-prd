-- =============================================================================
-- SafeTech — Segurança em Praças Públicas
-- 01_seed_dev.sql : dados iniciais para ambiente de desenvolvimento
-- ATENÇÃO: senhas abaixo são apenas para DEV. Todas valem "123456" (hash bcrypt gerado pela aplicação).
-- =============================================================================
SET search_path TO safetech, public;

-- -----------------------------------------------------------------------------
-- Categorias de ocorrência
-- -----------------------------------------------------------------------------
INSERT INTO categoria_ocorrencia (nome, descricao, gravidade_padrao) VALUES
    ('Iluminação precária',      'Postes apagados, lâmpadas queimadas ou áreas escuras',         'MEDIA'),
    ('Vandalismo',               'Depredação de bancos, brinquedos, lixeiras ou equipamentos',   'MEDIA'),
    ('Assalto / Roubo',          'Relato de assalto ou roubo ocorrido na praça',                 'ALTA'),
    ('Uso de drogas',            'Uso ou tráfico de entorpecentes no local',                     'ALTA'),
    ('Pessoa suspeita',          'Comportamento suspeito observado',                             'MEDIA'),
    ('Infraestrutura danificada','Piso quebrado, buracos, alambrado danificado etc.',            'BAIXA'),
    ('Equipamento de segurança', 'Câmera, botão de pânico ou totem com defeito',                 'ALTA'),
    ('Aglomeração / Briga',      'Tumulto, briga ou aglomeração com risco à segurança',          'CRITICA'),
    ('Outros',                   'Ocorrência que não se enquadra nas demais categorias',         'BAIXA')
ON CONFLICT (nome) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Usuários
-- -----------------------------------------------------------------------------
INSERT INTO usuario (id, nome, email, senha_hash, telefone, perfil, matricula) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Administrador SafeTech', 'admin@safetech.local',
     '$2b$10$Z2F7BxkNYyVFmcHZrUKxH.MiILg6Snfq/3bY2HYF96lVR/y2Pjs5i', '81999990001', 'ADMIN',   'ADM-0001'),
    ('22222222-2222-2222-2222-222222222222', 'Marina Gestora',         'gestor@safetech.local',
     '$2b$10$Z2F7BxkNYyVFmcHZrUKxH.MiILg6Snfq/3bY2HYF96lVR/y2Pjs5i', '81999990002', 'GESTOR',  'GST-0001'),
    ('33333333-3333-3333-3333-333333333333', 'Carlos Agente',          'agente@safetech.local',
     '$2b$10$Z2F7BxkNYyVFmcHZrUKxH.MiILg6Snfq/3bY2HYF96lVR/y2Pjs5i', '81999990003', 'AGENTE',  'AGT-0001'),
    ('44444444-4444-4444-4444-444444444444', 'Ana Cidadã',             'ana@exemplo.com',
     '$2b$10$Z2F7BxkNYyVFmcHZrUKxH.MiILg6Snfq/3bY2HYF96lVR/y2Pjs5i', '81999990004', 'CIDADAO', NULL),
    ('55555555-5555-5555-5555-555555555555', 'João Cidadão',           'joao@exemplo.com',
     '$2b$10$Z2F7BxkNYyVFmcHZrUKxH.MiILg6Snfq/3bY2HYF96lVR/y2Pjs5i', '81999990005', 'CIDADAO', NULL)
ON CONFLICT (email) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Praças (Recife/PE como exemplo)
-- -----------------------------------------------------------------------------
INSERT INTO praca (id, nome, descricao, logradouro, numero, bairro, cidade, uf, cep, latitude, longitude, area_m2, horario_abertura, horario_fechamento) VALUES
    ('aaaaaaaa-0000-0000-0000-000000000001', 'Praça do Derby',
     'Praça histórica com área verde, pista de caminhada e playground.',
     'Praça do Derby', 's/n', 'Derby', 'Recife', 'PE', '52010140', -8.056389, -34.897778, 25000, '05:00', '23:00'),
    ('aaaaaaaa-0000-0000-0000-000000000002', 'Praça de Casa Forte',
     'Praça arborizada com espelho d''água e quadra poliesportiva.',
     'Praça de Casa Forte', 's/n', 'Casa Forte', 'Recife', 'PE', '52061000', -8.034722, -34.916944, 12000, '05:00', '22:00'),
    ('aaaaaaaa-0000-0000-0000-000000000003', 'Praça do Marco Zero',
     'Marco histórico do Recife Antigo, área de eventos.',
     'Av. Alfredo Lisboa', 's/n', 'Recife', 'Recife', 'PE', '50030150', -8.063056, -34.871111, 8000, NULL, NULL)
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Equipamentos
-- -----------------------------------------------------------------------------
INSERT INTO equipamento (id, praca_id, tipo, codigo, descricao, localizacao, status, instalado_em) VALUES
    ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'CAMERA',       'CAM-DERBY-01', 'Câmera dome 360°',           'Entrada principal',      'OPERANTE',    '2025-03-10'),
    ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'CAMERA',       'CAM-DERBY-02', 'Câmera fixa',                'Playground',             'INOPERANTE',  '2025-03-10'),
    ('bbbbbbbb-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'BOTAO_PANICO', 'BTN-DERBY-01', 'Botão de pânico com interfone', 'Totem central',       'OPERANTE',    '2025-03-12'),
    ('bbbbbbbb-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', 'ILUMINACAO',   'ILU-DERBY-01', 'Poste LED inteligente',      'Pista de caminhada',     'OPERANTE',    '2025-02-01'),
    ('bbbbbbbb-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000002', 'CAMERA',       'CAM-CFORTE-01','Câmera dome 360°',           'Quadra',                 'OPERANTE',    '2025-04-20'),
    ('bbbbbbbb-0000-0000-0000-000000000006', 'aaaaaaaa-0000-0000-0000-000000000002', 'TOTEM',        'TTM-CFORTE-01','Totem de emergência',        'Entrada lateral',        'EM_MANUTENCAO','2025-04-20'),
    ('bbbbbbbb-0000-0000-0000-000000000007', 'aaaaaaaa-0000-0000-0000-000000000003', 'CAMERA',       'CAM-MZERO-01', 'Câmera PTZ',                 'Marco Zero',             'OPERANTE',    '2024-12-01')
ON CONFLICT (codigo) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Ocorrências (o protocolo e o histórico são gerados pelas triggers)
-- -----------------------------------------------------------------------------
INSERT INTO ocorrencia (id, praca_id, categoria_id, autor_id, titulo, descricao, gravidade, anonima, ocorrida_em) VALUES
    ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
     (SELECT id FROM categoria_ocorrencia WHERE nome = 'Iluminação precária'),
     '44444444-4444-4444-4444-444444444444',
     'Postes apagados perto do playground',
     'Três postes apagados há mais de uma semana na área do playground, deixando o local muito escuro à noite.',
     'MEDIA', FALSE, NOW() - INTERVAL '3 days'),
    ('cccccccc-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
     (SELECT id FROM categoria_ocorrencia WHERE nome = 'Assalto / Roubo'),
     NULL,
     'Assalto na saída da praça',
     'Relato de assalto a pedestre por volta das 21h na saída próxima à Av. Agamenon Magalhães.',
     'ALTA', TRUE, NOW() - INTERVAL '1 day'),
    ('cccccccc-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000002',
     (SELECT id FROM categoria_ocorrencia WHERE nome = 'Vandalismo'),
     '55555555-5555-5555-5555-555555555555',
     'Bancos pichados e lixeira quebrada',
     'Bancos próximos ao espelho d''água foram pichados e uma lixeira foi arrancada.',
     'BAIXA', FALSE, NOW() - INTERVAL '10 days')
ON CONFLICT (id) DO NOTHING;

-- Anexo de exemplo
INSERT INTO anexo_ocorrencia (ocorrencia_id, tipo, url, nome_arquivo, enviado_por) VALUES
    ('cccccccc-0000-0000-0000-000000000001', 'IMAGEM', 'https://storage.safetech.local/ocorrencias/poste-apagado.jpg', 'poste-apagado.jpg', '44444444-4444-4444-4444-444444444444');

-- Atendimento (move a ocorrência para EM_ATENDIMENTO via trigger)
INSERT INTO atendimento (ocorrencia_id, agente_id, atribuido_por) VALUES
    ('cccccccc-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222');

-- Ocorrência resolvida
UPDATE ocorrencia SET status = 'RESOLVIDA' WHERE id = 'cccccccc-0000-0000-0000-000000000003';

-- -----------------------------------------------------------------------------
-- Alertas
-- -----------------------------------------------------------------------------
INSERT INTO alerta (praca_id, equipamento_id, origem, gravidade, status, mensagem) VALUES
    ('aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000003', 'BOTAO_PANICO', 'CRITICA', 'NOVO',
     'Botão de pânico acionado no totem central.'),
    ('aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 'EQUIPAMENTO',  'MEDIA',   'NOVO',
     'Câmera CAM-DERBY-02 sem sinal há 2 horas.');

INSERT INTO alerta (praca_id, origem, gravidade, status, mensagem, criado_por) VALUES
    ('aaaaaaaa-0000-0000-0000-000000000003', 'MANUAL', 'ALTA', 'RECONHECIDO',
     'Evento de grande porte previsto para hoje à noite; reforçar rondas.', '22222222-2222-2222-2222-222222222222');

UPDATE alerta
   SET reconhecido_por = '22222222-2222-2222-2222-222222222222', reconhecido_em = NOW()
 WHERE status = 'RECONHECIDO' AND reconhecido_por IS NULL;

-- -----------------------------------------------------------------------------
-- Rondas
-- -----------------------------------------------------------------------------
INSERT INTO ronda (praca_id, agente_id, status, agendada_para, iniciada_em, finalizada_em, observacoes) VALUES
    ('aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'CONCLUIDA',
     NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day' + INTERVAL '45 minutes',
     'Ronda sem intercorrências. Confirmada falta de iluminação no playground.'),
    ('aaaaaaaa-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333', 'AGENDADA',
     NOW() + INTERVAL '6 hours', NULL, NULL, NULL);

-- -----------------------------------------------------------------------------
-- Avaliações
-- -----------------------------------------------------------------------------
INSERT INTO avaliacao_praca (praca_id, usuario_id, nota, comentario) VALUES
    ('aaaaaaaa-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444', 2, 'Muito escura à noite.'),
    ('aaaaaaaa-0000-0000-0000-000000000001', '55555555-5555-5555-5555-555555555555', 3, 'De dia é tranquila.'),
    ('aaaaaaaa-0000-0000-0000-000000000002', '44444444-4444-4444-4444-444444444444', 4, 'Bem iluminada e movimentada.');

-- -----------------------------------------------------------------------------
-- Notificações
-- -----------------------------------------------------------------------------
INSERT INTO notificacao (usuario_id, ocorrencia_id, titulo, mensagem) VALUES
    ('44444444-4444-4444-4444-444444444444', 'cccccccc-0000-0000-0000-000000000001',
     'Ocorrência em atendimento', 'Sua ocorrência sobre iluminação no playground foi atribuída a um agente.');

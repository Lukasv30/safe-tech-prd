-- =============================================================================
-- SafeTech — 02_seed_demo_cp3.sql : massa de dados para a demonstração do MVP
-- Idempotente (IDs fixos + ON CONFLICT DO NOTHING). Aplicar DEPOIS de 01_seed_dev.sql.
-- Objetivo: dashboard com séries de 30 dias, painel com fila variada, alertas em vários status.
-- =============================================================================
SET search_path TO safetech, public;

-- Dois cidadãos a mais (senha "123456", igual ao seed 01; não usados para login no Supabase)
INSERT INTO usuario (id, nome, email, senha_hash, telefone, perfil) VALUES
    ('66666666-6666-6666-6666-666666666666', 'Beatriz Cidadã', 'beatriz@exemplo.com',
     '$2b$10$Z2F7BxkNYyVFmcHZrUKxH.MiILg6Snfq/3bY2HYF96lVR/y2Pjs5i', '81999990006', 'CIDADAO'),
    ('77777777-7777-7777-7777-777777777777', 'Rafael Cidadão', 'rafael@exemplo.com',
     '$2b$10$Z2F7BxkNYyVFmcHZrUKxH.MiILg6Snfq/3bY2HYF96lVR/y2Pjs5i', '81999990007', 'CIDADAO')
ON CONFLICT (email) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Ocorrências dos últimos 30 dias (protocolo e histórico vêm das triggers).
-- criado_em acompanha ocorrida_em para o tempo médio de resolução fazer sentido.
-- -----------------------------------------------------------------------------
WITH dados (id, praca, categoria, autor, titulo, descricao, gravidade, anonima, dias_atras) AS (VALUES
    ('dddddddd-0000-0000-0000-000000000001'::uuid, 'aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'Iluminação precária',       '66666666-6666-6666-6666-666666666666'::uuid, 'Poste piscando na entrada norte',          'O poste da entrada norte pisca e apaga por minutos.',                  'MEDIA'::nivel_gravidade,   FALSE, 28),
    ('dddddddd-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Vandalismo',                '77777777-7777-7777-7777-777777777777', 'Brinquedo do playground quebrado',          'Balanço com corrente arrebentada, risco para crianças.',               'MEDIA',   FALSE, 26),
    ('dddddddd-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000002', 'Infraestrutura danificada', '44444444-4444-4444-4444-444444444444', 'Buraco na pista de caminhada',              'Buraco de uns 40 cm perto da quadra.',                                  'BAIXA',   FALSE, 25),
    ('dddddddd-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000003', 'Pessoa suspeita',           NULL,                                   'Grupo abordando turistas',                  'Grupo aborda turistas insistentemente perto do píer.',                 'MEDIA',   TRUE,  22),
    ('dddddddd-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000001', 'Uso de drogas',             NULL,                                   'Uso de drogas atrás do coreto',             'Toda noite, após as 22h.',                                              'ALTA',    TRUE,  20),
    ('dddddddd-0000-0000-0000-000000000006', 'aaaaaaaa-0000-0000-0000-000000000002', 'Iluminação precária',       '55555555-5555-5555-5555-555555555555', 'Quadra sem iluminação',                     'Os refletores da quadra não acendem há 3 dias.',                       'MEDIA',   FALSE, 18),
    ('dddddddd-0000-0000-0000-000000000007', 'aaaaaaaa-0000-0000-0000-000000000003', 'Equipamento de segurança',  '66666666-6666-6666-6666-666666666666', 'Câmera do Marco Zero virada para o chão',   'A câmera PTZ parece ter sido movida e filma só o piso.',               'ALTA',    FALSE, 15),
    ('dddddddd-0000-0000-0000-000000000008', 'aaaaaaaa-0000-0000-0000-000000000001', 'Assalto / Roubo',           NULL,                                   'Roubo de celular na pista',                 'Dois homens em moto levaram o celular de uma corredora às 6h.',        'ALTA',    TRUE,  12),
    ('dddddddd-0000-0000-0000-000000000009', 'aaaaaaaa-0000-0000-0000-000000000002', 'Aglomeração / Briga',       '77777777-7777-7777-7777-777777777777', 'Briga após jogo na quadra',                 'Confusão generalizada depois de partida de futsal.',                   'CRITICA', FALSE, 10),
    ('dddddddd-0000-0000-0000-000000000010', 'aaaaaaaa-0000-0000-0000-000000000001', 'Infraestrutura danificada', '44444444-4444-4444-4444-444444444444', 'Banco de concreto rachado',                 'Banco perto do lago com rachadura grande.',                            'BAIXA',   FALSE, 8),
    ('dddddddd-0000-0000-0000-000000000011', 'aaaaaaaa-0000-0000-0000-000000000003', 'Vandalismo',                '55555555-5555-5555-5555-555555555555', 'Pichação no monumento',                     'Pichação nova na base do marco.',                                      'MEDIA',   FALSE, 6),
    ('dddddddd-0000-0000-0000-000000000012', 'aaaaaaaa-0000-0000-0000-000000000001', 'Iluminação precária',       '66666666-6666-6666-6666-666666666666', 'Trecho escuro perto do estacionamento',     'Três postes seguidos apagados.',                                        'MEDIA',   FALSE, 4),
    ('dddddddd-0000-0000-0000-000000000013', 'aaaaaaaa-0000-0000-0000-000000000002', 'Pessoa suspeita',           NULL,                                   'Homem observando crianças no playground',   'Permanece horas sem criança acompanhando.',                            'ALTA',    TRUE,  2),
    ('dddddddd-0000-0000-0000-000000000014', 'aaaaaaaa-0000-0000-0000-000000000003', 'Outros',                    '77777777-7777-7777-7777-777777777777', 'Ambulante bloqueando acesso',               'Barracas fechando a rampa de acessibilidade.',                         'BAIXA',   FALSE, 1),
    ('dddddddd-0000-0000-0000-000000000015', 'aaaaaaaa-0000-0000-0000-000000000001', 'Equipamento de segurança',  '44444444-4444-4444-4444-444444444444', 'Botão de pânico sem resposta',              'Apertei o botão do totem e nada aconteceu.',                           'CRITICA', FALSE, 0)
)
INSERT INTO ocorrencia (id, praca_id, categoria_id, autor_id, titulo, descricao, gravidade, anonima, ocorrida_em, criado_em)
SELECT d.id, d.praca, c.id, d.autor, d.titulo, d.descricao, d.gravidade, d.anonima,
       NOW() - make_interval(days => d.dias_atras, hours => 3),
       NOW() - make_interval(days => d.dias_atras, hours => 2)
  FROM dados d JOIN categoria_ocorrencia c ON c.nome = d.categoria
ON CONFLICT (id) DO NOTHING;

-- Fluxo de atendimento: algumas em análise, algumas atendidas e resolvidas, uma cancelada
UPDATE ocorrencia SET status = 'EM_ANALISE'
 WHERE id IN ('dddddddd-0000-0000-0000-000000000011', 'dddddddd-0000-0000-0000-000000000013') AND status = 'ABERTA';

INSERT INTO atendimento (ocorrencia_id, agente_id, atribuido_por, iniciado_em, finalizado_em, relato)
SELECT o.id, '33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222',
       o.criado_em + INTERVAL '5 hours', o.criado_em + INTERVAL '2 days', 'Equipe da manutenção acionada e problema sanado.'
  FROM ocorrencia o
 WHERE o.id IN ('dddddddd-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-000000000003',
                'dddddddd-0000-0000-0000-000000000006', 'dddddddd-0000-0000-0000-000000000007', 'dddddddd-0000-0000-0000-000000000010')
   AND NOT EXISTS (SELECT 1 FROM atendimento a WHERE a.ocorrencia_id = o.id);

UPDATE ocorrencia SET status = 'RESOLVIDA'
 WHERE id IN ('dddddddd-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-000000000003',
              'dddddddd-0000-0000-0000-000000000006', 'dddddddd-0000-0000-0000-000000000010')
   AND status <> 'RESOLVIDA';

-- Atendimento ainda em curso (câmera do Marco Zero): fica EM_ATENDIMENTO
UPDATE atendimento SET finalizado_em = NULL, relato = NULL WHERE ocorrencia_id = 'dddddddd-0000-0000-0000-000000000007';

UPDATE ocorrencia SET status = 'CANCELADA' WHERE id = 'dddddddd-0000-0000-0000-000000000004' AND status <> 'CANCELADA';

-- -----------------------------------------------------------------------------
-- Alertas em vários estados
-- -----------------------------------------------------------------------------
INSERT INTO alerta (id, praca_id, equipamento_id, origem, gravidade, status, mensagem, reconhecido_por, reconhecido_em, encerrado_em, criado_em) VALUES
    ('eeeeeeee-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000005', 'EQUIPAMENTO', 'MEDIA',   'ENCERRADO',   'SEM SINAL em CAMERA CAM-CFORTE-01 (Quadra)',          '33333333-3333-3333-3333-333333333333', NOW() - INTERVAL '9 days', NOW() - INTERVAL '9 days', NOW() - INTERVAL '9 days 1 hour'),
    ('eeeeeeee-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000004', 'EQUIPAMENTO', 'BAIXA',   'FALSO_POSITIVO', 'FALHA em ILUMINACAO ILU-DERBY-01 (Pista de caminhada)', '22222222-2222-2222-2222-222222222222', NOW() - INTERVAL '6 days', NOW() - INTERVAL '6 days', NOW() - INTERVAL '6 days 2 hours'),
    ('eeeeeeee-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000007', 'EQUIPAMENTO', 'ALTA',    'RECONHECIDO', 'MOVIMENTO SUSPEITO em CAMERA CAM-MZERO-01 (Marco Zero)', '33333333-3333-3333-3333-333333333333', NOW() - INTERVAL '3 hours', NULL, NOW() - INTERVAL '4 hours'),
    ('eeeeeeee-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 'EQUIPAMENTO', 'ALTA',    'NOVO',        'RUIDO ALTO em CAMERA CAM-DERBY-01 (Entrada principal)', NULL, NULL, NULL, NOW() - INTERVAL '40 minutes'),
    ('eeeeeeee-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000006', 'BOTAO_PANICO', 'CRITICA', 'NOVO',       'Botão de pânico acionado em Entrada lateral',           NULL, NULL, NULL, NOW() - INTERVAL '12 minutes')
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Rondas e avaliações
-- -----------------------------------------------------------------------------
INSERT INTO ronda (id, praca_id, agente_id, status, agendada_para, iniciada_em, finalizada_em, observacoes) VALUES
    ('ffffffff-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'CONCLUIDA', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days' + INTERVAL '50 minutes', 'Quadra escura confirmada; refletores com disjuntor desarmado.'),
    ('ffffffff-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'CONCLUIDA', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days' + INTERVAL '35 minutes', 'Sem intercorrências.'),
    ('ffffffff-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333', 'EM_ANDAMENTO', NOW() - INTERVAL '1 hour', NOW() - INTERVAL '50 minutes', NULL, NULL),
    ('ffffffff-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'AGENDADA', NOW() + INTERVAL '1 day', NULL, NULL, NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO avaliacao_praca (praca_id, usuario_id, nota, comentario)
SELECT v.praca, v.usuario, v.nota, v.comentario
  FROM (VALUES
    ('aaaaaaaa-0000-0000-0000-000000000001'::uuid, '66666666-6666-6666-6666-666666666666'::uuid, 2, 'Evito passar depois das 20h.'),
    ('aaaaaaaa-0000-0000-0000-000000000001', '77777777-7777-7777-7777-777777777777', 3, 'Melhorou com as câmeras, mas ainda tem trechos escuros.'),
    ('aaaaaaaa-0000-0000-0000-000000000002', '66666666-6666-6666-6666-666666666666', 4, 'Movimentada, me sinto segura.'),
    ('aaaaaaaa-0000-0000-0000-000000000002', '77777777-7777-7777-7777-777777777777', 4, NULL),
    ('aaaaaaaa-0000-0000-0000-000000000003', '44444444-4444-4444-4444-444444444444', 3, 'De dia ótima, à noite depende do evento.'),
    ('aaaaaaaa-0000-0000-0000-000000000003', '66666666-6666-6666-6666-666666666666', 4, 'Muita polícia por perto.')
  ) AS v(praca, usuario, nota, comentario)
 WHERE NOT EXISTS (SELECT 1 FROM avaliacao_praca a WHERE a.praca_id = v.praca AND a.usuario_id = v.usuario);

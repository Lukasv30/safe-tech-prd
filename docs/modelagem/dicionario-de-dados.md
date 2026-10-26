# Dicionário de Dados — SafeTech

Descrição semântica de cada campo. Tipos e restrições técnicas estão em
[modelo-logico.md](modelo-logico.md); a DDL executável está em [`database/ddl/`](../../database/ddl/).

## usuario
| Campo | Significado |
|-------|-------------|
| id | Identificador único do usuário. |
| nome | Nome completo exibido na plataforma. |
| email | E-mail de login; único. |
| senha_hash | Hash da senha (bcrypt/argon2). |
| telefone | Telefone de contato, com DDD. |
| cpf | CPF somente dígitos; opcional para cidadão. |
| perfil | Papel na plataforma: CIDADAO, AGENTE, GESTOR ou ADMIN. |
| matricula | Matrícula funcional de agentes e gestores. |
| ativo | Indica se a conta está habilitada. |
| criado_em / atualizado_em | Auditoria de criação e última alteração. |

## praca
| Campo | Significado |
|-------|-------------|
| id | Identificador único da praça. |
| nome | Nome oficial ou popular da praça. |
| descricao | Texto livre (características, estrutura, histórico). |
| logradouro, numero, bairro, cidade, uf, cep | Endereço completo. |
| latitude, longitude | Coordenadas geográficas do centro da praça (WGS-84). |
| area_m2 | Área aproximada em metros quadrados. |
| horario_abertura / horario_fechamento | Horário de funcionamento; nulos quando aberta 24h. |
| ativa | Praça ainda monitorada pela plataforma. |

## equipamento
| Campo | Significado |
|-------|-------------|
| id | Identificador único do equipamento. |
| praca_id | Praça onde está instalado. |
| tipo | CAMERA, ILUMINACAO, BOTAO_PANICO, TOTEM, SENSOR_PRESENCA ou SENSOR_RUIDO. |
| codigo | Código de patrimônio / identificador físico; único. |
| descricao | Modelo, fabricante ou detalhes. |
| localizacao | Ponto de referência dentro da praça. |
| latitude, longitude | Posição exata do equipamento (opcional). |
| status | OPERANTE, INOPERANTE, EM_MANUTENCAO ou DESATIVADO. |
| instalado_em | Data de instalação. |
| ultima_manutencao | Data da última manutenção. |

## categoria_ocorrencia
| Campo | Significado |
|-------|-------------|
| id | Identificador sequencial. |
| nome | Nome da categoria (ex.: Iluminação precária). |
| descricao | Explicação do que se enquadra na categoria. |
| gravidade_padrao | Gravidade sugerida ao registrar uma ocorrência desta categoria. |
| ativa | Permite ocultar categorias sem apagar o histórico. |

## ocorrencia
| Campo | Significado |
|-------|-------------|
| id | Identificador único. |
| protocolo | Código público para acompanhamento (STC-AAAA-NNNNNN). |
| praca_id | Praça onde o fato ocorreu. |
| categoria_id | Categoria da ocorrência. |
| autor_id | Usuário que registrou; nulo quando anônima. |
| titulo | Resumo curto. |
| descricao | Relato detalhado. |
| gravidade | BAIXA, MEDIA, ALTA ou CRITICA. |
| status | ABERTA, EM_ANALISE, EM_ATENDIMENTO, RESOLVIDA ou CANCELADA. |
| anonima | Se TRUE, a identidade do autor não é exibida. |
| latitude, longitude | Ponto exato dentro da praça (opcional). |
| ocorrida_em | Data/hora em que o fato aconteceu. |
| resolvida_em | Data/hora da resolução. |

## anexo_ocorrencia
| Campo | Significado |
|-------|-------------|
| ocorrencia_id | Ocorrência à qual o anexo pertence. |
| tipo | IMAGEM, VIDEO, AUDIO ou DOCUMENTO. |
| url | Localização do arquivo no storage. |
| nome_arquivo | Nome original do arquivo. |
| tamanho_bytes | Tamanho do arquivo. |
| enviado_por | Usuário que enviou o anexo. |
| enviado_em | Data/hora do envio. |

## historico_ocorrencia
| Campo | Significado |
|-------|-------------|
| ocorrencia_id | Ocorrência alterada. |
| status_anterior | Status antes da mudança (nulo na criação). |
| status_novo | Status após a mudança. |
| usuario_id | Quem realizou a mudança; nulo quando automática. |
| observacao | Justificativa ou comentário. |
| alterado_em | Data/hora da mudança. |

## atendimento
| Campo | Significado |
|-------|-------------|
| ocorrencia_id | Ocorrência atendida. |
| agente_id | Agente responsável. |
| atribuido_por | Gestor que fez a atribuição. |
| iniciado_em | Início do atendimento. |
| finalizado_em | Fim do atendimento. |
| relato | Relato do agente sobre o que foi feito. |

## alerta
| Campo | Significado |
|-------|-------------|
| praca_id | Praça do alerta. |
| equipamento_id | Equipamento que gerou o alerta (quando aplicável). |
| ocorrencia_id | Ocorrência aberta a partir do alerta (quando aplicável). |
| origem | EQUIPAMENTO, BOTAO_PANICO ou MANUAL. |
| gravidade | BAIXA, MEDIA, ALTA ou CRITICA. |
| status | NOVO, RECONHECIDO, ENCERRADO ou FALSO_POSITIVO. |
| mensagem | Texto descritivo do alerta. |
| criado_por | Usuário que registrou o alerta manual. |
| reconhecido_por / reconhecido_em | Quem reconheceu o alerta e quando. |
| encerrado_em | Quando o alerta foi encerrado. |

## ronda
| Campo | Significado |
|-------|-------------|
| praca_id | Praça patrulhada. |
| agente_id | Agente responsável pela ronda. |
| status | AGENDADA, EM_ANDAMENTO, CONCLUIDA ou CANCELADA. |
| agendada_para | Data/hora planejada. |
| iniciada_em / finalizada_em | Execução real. |
| observacoes | Relato da ronda. |

## avaliacao_praca
| Campo | Significado |
|-------|-------------|
| praca_id | Praça avaliada. |
| usuario_id | Cidadão que avaliou. |
| nota | 1 (muito insegura) a 5 (muito segura). |
| comentario | Comentário opcional. |

## notificacao
| Campo | Significado |
|-------|-------------|
| usuario_id | Destinatário. |
| ocorrencia_id / alerta_id | Objeto relacionado (opcional). |
| titulo, mensagem | Conteúdo exibido. |
| lida / lida_em | Controle de leitura. |

# Requisitos — SafeTech

> Requisitos derivados do escopo do protótipo. Devem ser revisados pela equipe conforme as telas do Figma Make
> forem detalhadas em [docs/prototipo/README.md](../prototipo/README.md).

## Requisitos funcionais

| ID | Requisito | Perfil | Prioridade |
|----|-----------|--------|-----------|
| RF01 | Cadastrar-se e autenticar-se na plataforma (e-mail e senha). | Todos | Alta |
| RF02 | Consultar praças cadastradas em lista e mapa, com indicadores de segurança. | Todos | Alta |
| RF03 | Registrar ocorrência em uma praça informando categoria, descrição, gravidade, data/hora e local, com opção de anonimato. | Cidadão, Agente | Alta |
| RF04 | Anexar fotos/vídeos a uma ocorrência. | Cidadão, Agente | Média |
| RF05 | Acompanhar o status das próprias ocorrências pelo protocolo. | Cidadão | Alta |
| RF06 | Avaliar a sensação de segurança de uma praça (nota 1–5 e comentário). | Cidadão | Média |
| RF07 | Listar, filtrar (praça, categoria, status, gravidade, período) e detalhar ocorrências. | Agente, Gestor, Admin | Alta |
| RF08 | Atribuir ocorrência a um agente e registrar o atendimento (relato, início, fim). | Gestor, Agente | Alta |
| RF09 | Alterar o status da ocorrência, mantendo histórico de todas as mudanças. | Agente, Gestor | Alta |
| RF10 | Cadastrar e manter praças (endereço, geolocalização, horário). | Admin | Alta |
| RF11 | Cadastrar e manter equipamentos de segurança por praça, com status operacional. | Admin, Gestor | Média |
| RF12 | Receber alertas em tempo real (botão de pânico, equipamento com falha, alerta manual) e reconhecê-los/encerrá-los. | Agente, Gestor | Alta |
| RF13 | Converter um alerta em ocorrência. | Agente, Gestor | Média |
| RF14 | Agendar e registrar rondas por praça. | Gestor, Agente | Média |
| RF15 | Visualizar dashboard com indicadores por praça (ocorrências abertas, últimos 30 dias, alertas, equipamentos com problema, nota média). | Gestor, Admin | Alta |
| RF16 | Receber notificações sobre mudanças nas próprias ocorrências e alertas relevantes. | Todos | Média |
| RF17 | Gerenciar usuários e perfis de acesso. | Admin | Alta |

## Requisitos não funcionais

| ID | Requisito |
|----|-----------|
| RNF01 | Senhas armazenadas apenas como hash (bcrypt/argon2). |
| RNF02 | Dados pessoais tratados conforme a LGPD; ocorrências anônimas não expõem o autor. |
| RNF03 | Banco de dados PostgreSQL 15+ com integridade referencial e auditoria (`criado_em`, `atualizado_em`, histórico de status). |
| RNF04 | Interface responsiva (uso em smartphone no local da praça). |
| RNF05 | Alertas de botão de pânico devem ser exibidos aos agentes em até 5 segundos após o acionamento. |
| RNF06 | Disponibilidade alvo de 99% em horário de funcionamento das praças. |
| RNF07 | Código versionado em Git com revisão por Pull Request. |

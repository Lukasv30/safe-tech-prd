# Evidências de Testes da API — Carolina Siqueira (Checkpoint 2)

Este documento registra a validação dos endpoints e contratos da API do projeto **SafeTech**, utilizando a extensão REST Client no VS Code conforme o roteiro do Checkpoint 2.

## Resumo dos Testes Executados
* **Autenticação:** Cadastro (`/auth/v1/signup`), Login (`/auth/v1/token`) e validação de usuário logado (`/auth/v1/user`) realizados com sucesso, obtendo o token JWT para as rotas protegidas.
* **Endpoints Públicos:** Consulta de praças (`/rest/v1/praca`), resumo gerencial (`vw_praca_resumo`), categorias e bloqueio de acesso sem token (retorno 401 nas ocorrências abertas sem autenticação).
* **Endpoints Protegidos (Logado):** Consulta de perfil, ocorrências abertas, histórico, equipamentos da praça, alertas, atendimentos e rondas executados com sucesso utilizando o token Bearer.
* **Funções RPC e Negócio:** Testes de consulta de protocolo, registro de ocorrência anônima e identificada, atualização de status pela equipe, acionamento do botão de pânico e reconhecimento de alertas validados corretamente.

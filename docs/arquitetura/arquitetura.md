# Documento de Arquitetura — SafeTech (Checkpoint 2)

## 1. Visão Geral da Solução
O **SafeTech** é uma plataforma inteligente de segurança e gestão urbana voltada para praças públicas. O sistema conecta cidadãos, equipes de campo e gestores públicos para o monitoramento de ocorrências, equipamentos IoT e rondas.

* **Perfis de Usuário:**
  * **Cidadão:** Consulta praças, abre ocorrências (anônimas ou identificadas) e avalia locais.
  * **Agente / Equipe de Campo:** Atende chamados, atualiza status de ocorrências e reconhece alertas.
  * **Gestor:** Visualiza dashboards gerenciais e acompanha métricas da operação.

---

## 2. Arquitetura do Sistema
A arquitetura baseia-se em uma abordagem *serverless* e orientada a serviços utilizando o **Supabase** como *Backend-as-a-Service* (BaaS) e uma interface frontend em React.

```mermaid
graph TD
    A[Cidadão / Front-end React] -->|HTTPS / JWT| B[Supabase Auth]
    A -->|PostgREST API / RPC| C[(PostgreSQL Database)]
    D[Dispositivos IoT] -->|Edge Functions| C
    style C fill:#339933,stroke:#fff,stroke-width:2px

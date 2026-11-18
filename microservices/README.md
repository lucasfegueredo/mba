# Arquitetura de Microsserviços — Trabalho Final

Entrega de **modelagem** (sem código): extração do cadastro do monólito com Identity Service, saga cadastro+assinatura e message broker para projeção no legado.

## Arquivos

- [`docs/TRABALHO_FINAL.md`](docs/TRABALHO_FINAL.md) — planejamento completo
- [`docs/cadastro-message-broker.excalidraw`](docs/cadastro-message-broker.excalidraw) — abrir no Excalidraw (Menu → Open)
- [`docs/cadastro-saga-lucas.png`](docs/cadastro-saga-lucas.png) — PNG de apoio

Autor: Lucas Fegueredo Rodrigues.

### Serviços nomeados no diagrama

| Recurso | Tecnologia |
|---|---|
| `web-cadastro` | React |
| `bff-cadastro` | NestJS |
| `identity-service` + `identity-db` | Node.js + PostgreSQL |
| `assinatura-service` + `assinatura-db` | serviço existente + PostgreSQL |
| `rabbitmq` | exchange `user.events` |
| `user-projector` | consumer Node.js |
| `legacy-oracle` / `legacy-monolith` | projeção + JOIN local |

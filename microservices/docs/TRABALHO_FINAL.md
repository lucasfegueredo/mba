# Trabalho Final — Extração do Cadastro para Microsserviços

**Disciplina:** Arquitetura de Microsserviços  
**Tipo de entrega:** planejamento / modelagem (sem implementação de produção)  
**Objetivo do PO:** remover a dependência síncrona do cadastro em relação ao monólito (aplicação + banco) e habilitar cadastro + assinatura com confirmação síncrona na UX.

---

## 1. Contexto e problema

O monólito concentra ~50 domínios, serve HTML server-side e usa um Oracle compartilhado. O cadastro (email, nome, senha + unicidade de email) sofre indisponibilidade por contenção de recursos. A assinatura já existe fora do monólito. O PO quer:

1. Cadastro independente do monólito e do Oracle legado (de forma síncrona).
2. Opção de escolher um produto na tela de cadastro, com sucesso apenas se **usuário e assinatura** forem concluídos.
3. Em falha, a impressão deve ser de que **nada foi realizado**, e a retentativa com o mesmo email **não** pode retornar “email já cadastrado”.

---

## 2. Sistemas nomeados

| Sistema | Função |
|---|---|
| **Cadastro BFF** | Entrada do front de cadastro; orquestra a saga |
| **Identity Service** | Bounded context de usuário |
| **Identity DB** | Banco exclusivo do Identity (fonte da verdade) |
| **Assinatura Service** | Já existente; cria assinatura por `id_usuario` + produto |
| **Legacy Monolith** | Empréstimo, cobrança e demais domínios |
| **Legacy Oracle** | Banco do monólito; mantém **projeção** de usuários |
| **User Projector** | Consome eventos e atualiza a projeção no Legacy Oracle |
| **Event Bus** | Broker de eventos de usuário |

---

## 3. Princípios aplicados (aulas)

- **DDD / Bounded Context:** Usuário vira contexto próprio (Identity).
- **Database per Service:** Identity DB separado do Legacy Oracle.
- **Strangler Fig:** migração incremental; monólito convive com o novo serviço.
- **BFF / API Gateway:** Cadastro BFF encapsula a orquestração; o browser não fala com N serviços.
- **CQRS / Read Model:** monólito mantém projeção local de usuário para JOINs (evita Composition síncrona no hot path).
- **Saga (orquestração) + compensação:** em vez de 2PC; estados `PENDENTE` e job de purga.
- **Não piorar o monólito:** nenhuma chamada síncrona nova nas telas de gestão.

---

## 4. Fluxo de mudanças (etapas)

### Etapa 0 — As-Is
Inventário de FKs, joins e contratos do Assinatura Service. Sem mudança de comportamento.

### Etapa 1 — Identity Service + Identity DB + migração
1. Criar Identity Service e Identity DB.
2. **Bulk load** dos usuários existentes (preservar `id_usuario`).
3. **Dual-write ou CDC/outbox** enquanto o monólito ainda é o writer.
4. Job de **reconciliação** para drifts.
5. Cadastro ainda no monólito (sem mudança de UX).

> Conversa com o PO: migração transparente, sem indisponibilidade planejada.

### Etapa 2 — Desacoplar joins e FKs
1. Tabela `usuario` no Legacy Oracle passa a ser **projeção** (CQRS).
2. Remover FKs físicas que impedem o desacoplamento; manter `id_usuario` como referência lógica.
3. User Projector aplica eventos (`UserConfirmed`, etc.) de forma assíncrona.
4. Listagem de empréstimos continua com `JOIN` **local** na projeção.

**Por que não Composition Pattern no monólito?**  
Chamar Identity Service a cada listagem soma latência, timeouts e contende recursos — exatamente o que o PO quer evitar (ponto 5).

> Conversa com o PO: aceitar consistência eventual curta nos nomes exibidos nas telas de gestão.

### Etapa 3 — Strangler do cadastro (primeira entrega de valor)
1. Novo front de cadastro + **Cadastro BFF**.
2. `POST /cadastro` → BFF → Identity Service → Identity DB.
3. Evento `UserConfirmed` → User Projector → projeção no Legacy Oracle.
4. Desligar cadastro e dual-write no monólito.
5. Feature flag / cutover gradual com rollback.

**Resultado:** cadastro sem dependência síncrona do monólito nem do Oracle legado.

### Etapa 4 — Cadastro + Assinatura (Saga)
Usabilidade exige confirmação **síncrona** da assinatura no momento do cadastro (ponto 7). Usamos saga orquestrada no BFF.

---

## 5. Saga: cadastro + assinatura (maior desafio)

### Modelo de dados (Identity)
- `id_usuario`
- `email`
- `nome`
- `senha_hash`
- `status`: `PENDENTE` | `ATIVO` | `CANCELADO`
- `tentativa_id` (idempotência)
- `expires_at` (para PENDENTE)

**Unicidade:** e-mail único efetivo para `ATIVO` (unique parcial / regra de aplicação).  
`PENDENTE` faz **upsert por e-mail**.

### Fluxo feliz
1. Usuário envia email, nome, senha e produto.
2. Cadastro BFF gera `tentativa_id`.
3. Identity: cria/atualiza usuário `PENDENTE` (upsert por email).
4. Assinatura Service: cria assinatura `PENDENTE` com `id_usuario` + produto + `tentativa_id`.
5. BFF confirma usuário (`ATIVO`) e confirma assinatura (`ATIVA`) no mesmo request.
6. Emite `UserConfirmed` para a projeção do monólito.
7. Responde sucesso ao usuário.

### Falhas e retentativas (ponto 6)

| Cenário | Comportamento |
|---|---|
| Timeout/erro ao criar usuário | Nada fica `ATIVO`; retentativa livre com o mesmo email |
| Usuário `PENDENTE` ok, assinatura falha | Usuário **não** vira `ATIVO`; retentativa faz upsert do `PENDENTE` — **sem** “email já cadastrado” |
| Assinatura ok, falha na confirmação do usuário | Idempotência por `tentativa_id` + job cancela assinatura órfã |
| Abandono | Job de purga remove `PENDENTE` expirados (desfazimento por padrão, como nas aulas) |

### Por que não 2PC?
2PC reduz disponibilidade e acopla os serviços. A aula de Data Management modela exatamente esse trade-off com estados pendentes, confirmação e purga.

### Por que a assinatura não pode ser só assíncrona?
O PO exigiu confirmação no momento do cadastro. A assíncronia fica só na **projeção** para o monólito (que não faz parte da resposta ao usuário do cadastro).

---

## 6. Migração de dados (ponto 2)

1. **Snapshot/bulk:** `INSERT INTO identity.usuario SELECT ... FROM legacy.usuario`.
2. **Sync contínuo** (dual-write via outbox/CDC) até o cutover.
3. **Reconciliação** por contagem e amostra de hashes.
4. Cutover do writer para Identity Service.
5. Legacy Oracle mantém apenas projeção (não é mais fonte da verdade).

Sem janela longa de indisponibilidade; cutover com feature flag.

---

## 7. FKs e queries do monólito (pontos 3, 4 e 5)

- FKs físicas cross-database **não existem** após a extração.
- Substituir por referência lógica (`id_usuario`) + validação eventual via eventos.
- Telas com JOIN (empréstimos) leem a **projeção local**.
- Evitar API Composition síncrona no monólito para não aumentar indisponibilidade.

---

## 8. Entregas e validação com o PO (ponto 8)

| Entrega | Valor |
|---|---|
| Etapa 1–2 | Fundação sem mudança de UX |
| **Etapa 3** | Cadastro mais disponível/escalável (objetivo principal do PO) |
| **Etapa 4** | Feature de produto no cadastro com garantia síncrona |

Não é um projeto “big bang” de anos: cada etapa é publicável e reversível.

---

## 9. Proposta formal ao PO (resumo)

1. Migrar usuários para Identity DB sem downtime perceptível.
2. Aceitar atraso mínimo (consistência eventual) no nome do usuário nas telas de gestão.
3. Manter formulário simples; na etapa 4, incluir select de produto.
4. Em erro de cadastro+assinatura, mensagem: “Não foi possível concluir. Tente novamente.”
5. Assinatura continua confirmada de forma síncrona na UX.

---

## 10. Diagrama mental final

```
[Front Cadastro] → [Cadastro BFF] ┬→ [Identity Service] → [Identity DB]
                                 └→ [Assinatura Service] → [Assinatura DB]
                                         │
                                         ▼ (eventos)
                                   [Event Bus] → [User Projector] → [Legacy Oracle projeção]
                                                                      ▲
                                                         [Legacy Monolith] JOIN local
```

# Jubify 🌱

> *La pensión que el sistema no te dio*

Jubify es un protocolo de jubilación descentralizado con inteligencia artificial on-chain. Cualquier persona puede construir su fondo de retiro desde su email, sin wallet, sin conocimientos de crypto, y sin depender de ningún Estado o institución financiera.

**Hackathon Aleph — Crecimiento 2026 · Tracks: GenLayer + Avalanche + PL**

---

## El problema

- El 90% de la población mundial no tiene una pensión suficiente (OIT)
- 140 millones de trabajadores informales en Latinoamérica sin cobertura previsional
- Los sistemas formales también fallan: en Argentina el 65% de jubilados cobra menos que el salario mínimo
- La tasa de natalidad cayó a 1.8 hijos por mujer en la región — la pirámide poblacional se invirtió para siempre

María enseñó 35 años. Aportó cada mes, sin falta. Se jubiló y la pensión no le alcanza para pagar el alquiler. El sistema cumplió. Y aun así, falló. Jubify existe para todas las Marías.

---

## La solución

Jubify combina **Avalanche C-Chain** para la custodia y ejecución de fondos con **GenLayer Intelligent Contracts** para el asesoramiento financiero autónomo on-chain.

El usuario entra con su email, describe su situación en texto libre, y un Intelligent Contract analiza su perfil consultando datos de mercado en tiempo real para generar un plan de jubilación personalizado — verificado por consenso de múltiples validadores con diferentes LLMs.

**Experiencia Web2. Backend Web3.**

---

## Arquitectura

```
Usuario (email / wallet)
        ↓
  RetiroAI.py — GenLayer Intelligent Contract
  · Lee APYs reales desde la web
  · Interpreta perfil en lenguaje natural
  · Genera asignación verificada on-chain
  · Consenso entre 5 validadores con LLMs distintos
        ↓
  RetiroVault.sol — Avalanche C-Chain
  · Vault self-custodial (nadie más puede tocar los fondos)
  · Staking AVAX + yield USDC + Benqi
  · Dead man's switch + herencia digital automática
  · Retiro programado mensual / semestral / anual
  · Fondo social comunitario (penalidades de retiro anticipado)
        ↓
  Backend — Fastify + TypeScript (este repo)
  · API modular con modo mock/hybrid/real
  · Adapters para Avalanche y GenLayer
  · Modo degradado elegante para demo
        ↓
  Frontend — React + Vite + TailwindCSS
  · Login con email via Privy
  · Depósitos en fiat (Manteca / Cobre) o cripto
  · Dashboard de proyección a 30 años
  · Simulador de retiro interactivo
```

---

## Features

- **Self-custodial** — nadie puede mover tus fondos excepto vos. Ni nosotros.
- **IA on-chain** — razonamiento financiero verificado en GenLayer, no en nuestros servidores
- **Dead man's switch** — herencia digital automática sin trámites ni abogados
- **Retiro programado** — pensión mensual automática al jubilarte, fondo sigue generando yield
- **Fondo social** — penalidades de retiro anticipado alimentan un pool comunitario solidario
- **Web2 UX / Web3 backend** — entrás con email, tu fondo vive en la blockchain
- **Fiat + crypto** — depósitos en pesos argentinos, colombianos, reales o AVAX via Manteca/Cobre

---

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| IA on-chain | GenLayer Intelligent Contracts (Python) |
| Vault / custodia | Avalanche C-Chain — Solidity 0.8.20 |
| Backend | Fastify + TypeScript + Zod |
| Wallet por email | Privy SDK |
| Onramp / Offramp fiat | Manteca / Cobre |
| Frontend | React + Vite + TailwindCSS |
| Interacción contratos | ethers.js + genlayer-js |

---

## Contratos deployados

| Contrato | Red | Dirección |
|---|---|---|
| JubifyVault.sol | Avalanche Fuji Testnet | `0xc412Ee4323B11F76df3D96FD11BB74e2d2E26886` |
| RetiroAI.py | GenLayer Testnet | `0x...` |

---

## Backend

Backend modular, tipado y demo-first para JUBIFY.

### Qué trae

- Fastify + TypeScript
- Validación estricta con Zod
- Arquitectura modular simple
- Repositorios in-memory listos para demo
- Session auth simple para prototipo
- Event log / audit trail
- Dashboard consolidado
- Adapters mock y reales para Avalanche y GenLayer
- Modo degradado elegante si las integraciones fallan

### Filosofía

Esto levanta **sin base externa**.  
La persistencia por defecto es en memoria para no matar la demo.  
La siguiente capa natural es agregar PostgreSQL/Prisma sin romper contratos ni servicios.

### Requisitos

- Node.js 22+
- npm 10+

### Instalación

```bash
npm install
cp .env.example .env
npm run dev
```

Servidor por defecto en `http://localhost:3001`

### Scripts

```bash
npm run dev      # desarrollo
npm run build    # compilar
npm run start    # producción
npm run check    # typecheck
```

### Modos de integración

- `mock`: usa siempre providers mock.
- `hybrid`: intenta provider real y si falla, cae a mock.
- `real`: intenta provider real; si falla, responde con degradación y último fallback disponible.

### Flujo mínimo de prueba

**1) Login demo**

```bash
curl -X POST http://localhost:3001/auth/demo-login \
  -H "content-type: application/json" \
  -d '{"demoUser":"default"}'
```

Guarda `accessToken`.

**2) Consultar onboarding**

```bash
curl http://localhost:3001/onboarding/state \
  -H "authorization: Bearer TU_TOKEN"
```

**3) Ver dashboard**

```bash
curl http://localhost:3001/dashboard/usr_demo_001 \
  -H "authorization: Bearer TU_TOKEN"
```

### Variables importantes

**Core**
- `APP_MODE=demo`
- `INTEGRATION_MODE=mock|hybrid|real`

**Avalanche**
- `AVALANCHE_RPC_URL`
- `AVALANCHE_CHAIN_ID`
- `AVALANCHE_VAULT_ADDRESS`

**GenLayer**
- `GENLAYER_API_URL`
- `GENLAYER_FROM_ADDRESS`
- `GENLAYER_CONTRACT_ADDRESS`
- `GENLAYER_PROTECTION_CALL_DATA`
- `GENLAYER_RETIREMENT_CALL_DATA`
- `GENLAYER_PROOF_OF_LIFE_CALL_DATA`

### Notas sobre GenLayer real

El adapter real usa:
- `GET /health` para health
- JSON-RPC `gen_call` cuando hay `contract address`, `from address` y `call data` configurados

Mientras esos hex payloads no estén definidos, el backend sigue funcionando y cae elegantemente al mock. Exactamente como debe ser una demo con autoestima.

### Estructura

```
src/
  config/
  domain/
  infra/
  modules/
  shared/
  types/
```

### Endpoints

**Auth**
- `POST /auth/demo-login`
- `POST /auth/email-login`
- `POST /auth/wallet-connect`

**Onboarding / Profile**
- `GET /onboarding/state`
- `POST /onboarding/profile`
- `POST /onboarding/preferences`

**Plan**
- `POST /plan`
- `GET /plan/:userId`
- `PATCH /plan/:userId/contribution`

**Retirement**
- `POST /plan/:userId/retirement`
- `GET /plan/:userId/retirement`

**Protection / Inheritance**
- `POST /plan/:userId/protection`
- `POST /plan/:userId/inheritance`
- `GET /plan/:userId/inheritance`

**Events**
- `GET /plan/:userId/events`

**Dashboard**
- `GET /dashboard/:userId`

**Health / Integrations**
- `GET /health`
- `GET /integrations/status`

### Siguiente paso lógico

1. levantar esto,
2. conectar frontend,
3. congelar contratos,
4. recién ahí meter Prisma/PostgreSQL,
5. después adapters reales con ABI/contract payloads definitivos.

---

## Roadmap

- [ ] Integración real con Privy para wallets por email
- [ ] Onramp/offramp fiat via Manteca
- [ ] Colateral para préstamos de emergencia (Benqi)
- [ ] Gobernanza DAO del fondo social
- [ ] PostgreSQL / Prisma para persistencia en producción

---

## Equipo

Construido en el Aleph Hackathon 2026 — Crecimiento.

---

*Jubify — Empezá con lo que tenés. Tu fondo crece solo.*

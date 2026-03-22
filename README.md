# Jubify 🌱

> *La pensión que el sistema no te dio.*

Jubify es un protocolo de jubilación descentralizado con inteligencia artificial on-chain. Cualquier persona puede construir su fondo de retiro desde su email, sin wallet, sin conocimientos de crypto, y sin depender de ningún Estado o institución financiera.

**Hackathon Aleph — Crecimiento 2026 · Tracks: GenLayer + Avalanche**

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
  JubifyAI.py — GenLayer Intelligent Contract
  · Interpreta perfil en lenguaje natural
  · Genera asignación verificada on-chain
  · Consenso entre 5 validadores con LLMs distintos
        ↓
  JubifyVault.sol — Avalanche C-Chain
  · Vault self-custodial
  · Staking AVAX + yield USDC + Benqi
  · Dead man's switch + herencia digital automática
  · Retiro programado mensual / semestral / anual
  · Fondo social comunitario
        ↓
  Backend — Fastify + TypeScript
  · API modular mock/hybrid/real
  · Adapters para Avalanche y GenLayer
        ↓
  Frontend — React + Vite + TailwindCSS
  · Login con email via Privy
  · Depósitos en fiat via Manteca/Cobre
  · Dashboard de proyección a 30 años
```

---

## Features

- **Self-custodial** — nadie puede mover tus fondos excepto vos. Ni nosotros.
- **IA on-chain** — razonamiento financiero verificado en GenLayer
- **Dead man's switch** — herencia digital automática sin trámites
- **Retiro programado** — pensión mensual automática al jubilarte
- **Fondo social** — penalidades alimentan un pool comunitario solidario
- **Web2 UX / Web3 backend** — entrás con email, tu fondo vive en la blockchain
- **Fiat + crypto** — depósitos en pesos o AVAX via Manteca/Cobre

---

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| IA on-chain | GenLayer Intelligent Contracts (Python) |
| Vault / custodia | Avalanche C-Chain — Solidity 0.8.29 |
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
| JubifyAI.py | GenLayer Testnet | `0x166509bca3ABe1275041884331D391ACFd723418` |

---

## Backend

Backend modular, tipado y demo-first para JUBIFY.

### Instalación
```bash
npm install
cp .env.example .env
npm run dev
```

Servidor en `http://localhost:3001`

### Modos de integración

- `mock` — providers simulados, ideal para demo
- `hybrid` — intenta real, cae a mock si falla
- `real` — provider real con degradación elegante

---

## Roadmap

- [ ] Integración real con Privy para wallets por email
- [ ] Onramp/offramp fiat via Manteca
- [ ] Colateral para préstamos de emergencia (Benqi)
- [ ] Gobernanza DAO del fondo social

---

## Equipo

Construido en el Aleph Hackathon 2026 — Crecimiento.

---

*Jubify — Empezá con lo que tenés. Tu fondo crece solo.*

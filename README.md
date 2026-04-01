# Jubify 🌱

> *La pensión que el sistema no te dio.*

Jubify es un protocolo de ahorro previsional voluntario descentralizado. Cualquier persona puede construir su fondo de retiro desde su email, sin wallet, sin conocimientos de crypto, y sin depender de ningún Estado o institución financiera.

**Hackathon:** Aleph — Crecimiento 2026 · **Tracks:** GenLayer Bradbury + PL Genesis: Frontiers of Collaboration

**Contratos deployados:**

| Contrato | Red | Dirección |
|---|---|---|
| `JubifyVault.sol` | Avalanche Fuji Testnet | `0xc412Ee4323B11F76df3D96FD11BB74e2d2E26886` |
| `JubifyAI.py` | GenLayer Testnet | `0x166509bca3ABe1275041884331D391ACFd723418` |

---

## El problema

El 90% de la población mundial no tiene una pensión suficiente (OIT). En Latinoamérica, 140 millones de trabajadores informales no tienen cobertura previsional. En Argentina, el 65% de jubilados cobra menos que el salario mínimo — y la tasa de natalidad cayó a 1.8 hijos por mujer, invirtiendo para siempre la pirámide poblacional.

María enseñó 35 años. Aportó cada mes. Se jubiló y la pensión no le alcanza para pagar el alquiler. El sistema cumplió. Y aun así, falló. **Jubify existe para todas las Marías.**

---

## La solución

Jubify combina tres capas técnicas para entregar una experiencia Web2 con backend completamente descentralizado:

- **`JubifyVault.sol` en Avalanche C-Chain** — custodia self-custodial del fondo, retiro programado mensual, proof-of-life, dead man's switch y herencia digital automática.
- **`JubifyAI.py` en GenLayer** — Intelligent Contract que lee el perfil financiero del usuario directamente desde IPFS y genera recomendaciones de asignación verificadas por consenso de múltiples validadores con LLMs distintos.
- **Storacha / IPFS / Filecoin** — los perfiles financieros y decisiones AI se archivan por CID. El usuario es dueño de sus datos, no solo de sus fondos.

---

## Arquitectura

```
Usuario (email / wallet)
        ↓
  Frontend — React + Vite + TailwindCSS
  Login con email vía Privy · Depósitos fiat vía Manteca/Cobre
        ↓
  Backend — Fastify + TypeScript
  Auth · Onboarding · Plan · Retirement · Protection · Dashboard
  Integrations: Avalanche / GenLayer / Storacha
  Retirement Passport Service
        ↓
  Storacha / IPFS / Filecoin
  Almacena snapshots derivados (RetirementPassport, AIDecision,
  MarketSnapshot, LivenessRecord) por CID inmutable
        ↓
  JubifyAI.py — GenLayer Intelligent Contract
  Lee snapshot por URL/CID · Consenso multi-LLM (gl.eq_principle)
  Emite decisión compacta: ALLOW / WATCH / REBALANCE / BLOCK
        ↓
  JubifyVault.sol — Avalanche C-Chain
  Custodia ERC20 · Retiro programado · Proof-of-life
  Dead man's switch · Herencia automática · Referencias CID on-chain
```

---

## Retirement Passport — Storacha / IPFS / Filecoin

Cuando un usuario configura su plan, el backend genera un `RetirementPassport` — un JSON con su perfil financiero — y lo sube a Storacha. El CID resultante queda registrado on-chain en el Vault.

**Por qué importa:** Jubify ya prometía que nadie puede mover tus fondos excepto vos. Con el Retirement Passport, esa promesa se extiende a tus datos: nadie puede mover, modificar ni perder tu información financiera tampoco. La autocustodia deja de ser solo sobre el dinero.

El `JubifyAI.py` lee el perfil directamente desde el gateway IPFS usando `gl.nondet.web.get` con `gl.eq_principle.strict_eq` — sin pasar por el backend, sin confiar en un servidor centralizado. Si Jubify cierra mañana, el contrato inteligente sigue funcionando.

```python
def fetch_passport_json() -> str:
    response = gl.nondet.web.get(passport_url)   # URL basada en CID de Storacha
    return response.body.decode("utf-8")

passport_json = gl.eq_principle.strict_eq(fetch_passport_json)
```

---

## GenLayer — Por qué usamos Intelligent Contracts

Los smart contracts tradicionales son determinísticos: no pueden evaluar si una estrategia de inversión es razonable para una persona de 45 años con tolerancia moderada al riesgo y 20 años de horizonte. Eso requiere juicio.

GenLayer resuelve esto con **Optimistic Democracy**: múltiples validadores ejecutan el contrato con LLMs distintos y llegan a consenso sobre la respuesta más razonable — no la idéntica, sino la equivalente según criterios explícitos.

En Jubify, `JubifyAI.py` evalúa el perfil del usuario contra un snapshot de mercado normalizado y emite una decisión estructurada:

```json
{
  "decision": "ALLOW",
  "recommendedStrategy": "BALANCED",
  "recommendedProtocol": "aave-v3",
  "confidence": "medium",
  "maxAllocationPct": 60,
  "reasonShort": "Balanced profile and candidate quality are aligned."
}
```

Usamos `gl.eq_principle.strict_eq` para el fetch del perfil desde IPFS (determinístico por content addressing) y `gl.eq_principle.prompt_non_comparative` para la evaluación financiera (subjetiva, requiere razonamiento). **La elección del principio de equivalencia correcto para cada etapa es intencional.**

---

## JubifyVault.sol — Features principales

- **Self-custodial** — nadie puede mover los fondos excepto el usuario.
- **Retiro programado** — pensión mensual/trimestral automática al jubilarse.
- **Proof-of-life + Dead man's switch** — herencia digital sin trámites si el usuario deja de hacer check-in.
- **Fondo social** — penalidades alimentan un pool comunitario solidario.
- **Referencias CID on-chain** — `profileCID`, `decisionCID`, `inheritanceCID`, `livenessCID` quedan registrados como mappings públicos.
- **AccessControl + ReentrancyGuard + Pausable** — seguridad production-grade.

---

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| IA on-chain | GenLayer Intelligent Contracts (Python) |
| Vault / custodia | Avalanche C-Chain — Solidity 0.8.29 |
| Almacenamiento decentralizado | Storacha / IPFS / Filecoin |
| Backend | Fastify + TypeScript + Zod |
| Wallet por email | Privy SDK |
| Onramp / Offramp fiat | Manteca / Cobre |
| Frontend | React + Vite + TailwindCSS |
| Interacción contratos | ethers.js + genlayer-js |

---

## Estructura del repositorio

```
JubifyVault.sol        — Smart contract Avalanche (Solidity 0.8.29)
JubifyAI.py            — Intelligent Contract GenLayer (Python)
jubify-backend.zip     — Backend Fastify + TypeScript (código fuente completo)
jubify-frontend.zip    — Frontend React + Vite
README.md              — Este archivo
```

El backend incluye:
- módulo Storacha completo (`storacha.adapter`, `storacha.service`, `storacha-artifacts.service`)
- `RetirementPassportService` para generar y archivar perfiles
- rutas REST para sincronización manual de artifacts
- fallback elegante si Storacha, Avalanche o GenLayer no están disponibles
- modo demo con datos seed para presentaciones

---

## Cómo correr el backend

```bash
unzip jubify-backend.zip
cd jubify-backend
cp .env.example .env
npm install
npm run dev
# → http://localhost:3001
# → GET /integrations/status incluye avalanche, genlayer y storacha
```

Variables clave en `.env`:

```env
INTEGRATION_MODE=mock          # mock | hybrid | real
STORACHA_ENABLED=false         # true cuando tenés el token
STORACHA_AUTH_TOKEN=           # token de Storacha
AVALANCHE_VAULT_ADDRESS=       # dirección del vault deployado
GENLAYER_CONTRACT_ADDRESS=     # dirección del AI contract
```

---

## Principios de diseño

Este repositorio no intenta vender una fantasía de "agente autónomo que hace todo solo". La arquitectura está pensada para:

- **demo seria y estable** — el backend levanta sin ninguna integración externa,
- **backend demo-first** — modo `mock` funciona sin Avalanche, GenLayer ni Storacha,
- **contratos claros y acotados** — cada contrato hace exactamente una cosa,
- **fallback elegante** — si una integración falla, el sistema degrada, no explota,
- **Storacha como capa derivada** — no es la fuente de verdad, es la capa de auditoría inmutable.

---

## Roadmap

- [ ] Integración real con Privy para wallets por email
- [ ] Onramp/offramp fiat via Manteca
- [ ] Colateral para préstamos de emergencia (Benqi)
- [ ] Escritura de CIDs on-chain activada por defecto
- [ ] Gobernanza DAO del fondo social

---

## Equipo

Construido en el Aleph Hackathon 2026 — Crecimiento · Buenos Aires, Argentina.

---

*Jubify — Empezá con lo que tenés. Tu fondo crece solo.*

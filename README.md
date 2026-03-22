# JUBIFY contracts

Files:
- `JubifyVault.sol` — Avalanche C-Chain vault/coordinator (ERC-20 based)
- `JubifyAI.py` — GenLayer Intelligent Contract for allocation/risk monitoring

## Integration model

1. Backend reads/normalizes market data (for example DefiLlama TVL/APY snapshots).
2. Backend calls `JubifyAI.evaluate_plan(...)` or `JubifyAI.monitor_position(...)`.
3. Backend parses the decision JSON returned by GenLayer.
4. Backend/keeper executes the allowed on-chain action on `JubifyVault`.
5. Frontend reads the backend read model / audit timeline.

## Why this split

- Keep market-data fetching and AI reasoning off the Solidity contract.
- Keep custody, withdrawals, inheritance and auditable state transitions on Avalanche.
- Avoid coupling a vault to unstable external data sources.

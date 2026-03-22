# { "Depends": "py-genlayer:1jb45aa8ynh2a9c9xn3b7qqh8sm5q93hwfp7jqmwsfhh8jpz09h6" }
from genlayer import *
import json


class JubifyAI(gl.Contract):
    """
    Intelligent Contract for JUBIFY.

    Purpose:
    - Receives normalized JSON snapshots from the backend.
    - Produces consensus-backed recommendations for allocation and monitoring.
    - Keeps only compact, auditable outputs on-chain.

    IMPORTANT:
    - DefiLlama fetching should happen in the backend/adapters layer.
    - This contract evaluates normalized market data; it does not need to scrape UIs.
    - Returned JSON is intentionally compact so the backend can map it to dashboard/events.
    """

    profiles: TreeMap[Address, str]
    allocation_decisions: TreeMap[Address, str]
    monitoring_decisions: TreeMap[Address, str]

    def __init__(self):
        pass

    @gl.public.write
    def evaluate_plan(self, profile_json: str, market_snapshot_json: str) -> None:
        """
        Input contract:
        - profile_json: normalized profile/preferences from backend
        - market_snapshot_json: normalized market snapshot already filtered by backend

        Expected profile example:
        {
          "riskTolerance": "moderate",
          "timeHorizonYears": 20,
          "preferences": ["capital_preservation", "simple_withdrawals"]
        }

        Expected market example:
        {
          "chain": "Avalanche",
          "asset": "USDC",
          "candidates": [
            {"project": "aave-v3", "apy": 4.2, "tvlUsd": 1200000000, "exposure": "single"},
            {"project": "benqi", "apy": 5.1, "tvlUsd": 210000000, "exposure": "single"}
          ]
        }
        """
        profile = json.loads(profile_json)
        market = json.loads(market_snapshot_json)

        combined = json.dumps(
            {
                "profile": profile,
                "market": market,
            },
            sort_keys=True,
            separators=(",", ":"),
        )

        task = """
You are the policy-and-risk evaluator for a retirement savings product.
Read the normalized input JSON and return ONLY minified JSON with this exact schema:
{
  "decision":"ALLOW|WATCH|REBALANCE|BLOCK",
  "recommendedStrategy":"CONSERVATIVE|BALANCED|GROWTH",
  "recommendedProtocol":"string",
  "confidence":"low|medium|high",
  "maxAllocationPct":0,
  "reasonShort":"string"
}
"""

        criteria = """
- Output MUST be valid minified JSON and nothing else.
- decision must be one of: ALLOW, WATCH, REBALANCE, BLOCK.
- recommendedStrategy must be one of: CONSERVATIVE, BALANCED, GROWTH.
- recommendedProtocol must name one candidate present in the market snapshot, unless decision is BLOCK.
- maxAllocationPct must be an integer between 0 and 100.
- reasonShort must be short, factual, and must not invent external data.
- Higher APY alone is NOT enough; also consider TVL and user risk profile.
- For conservative profiles, prefer lower-risk / simpler exposure.
- If candidates look weak or inconsistent, choose WATCH or BLOCK rather than hallucinating certainty.
"""

        result = gl.eq_principle.prompt_non_comparative(
            lambda: combined,
            task=task,
            criteria=criteria,
        )

        self.profiles[gl.message.sender_address] = profile_json
        self.allocation_decisions[gl.message.sender_address] = result

    @gl.public.write
    def monitor_position(self, position_snapshot_json: str, market_snapshot_json: str) -> None:
        """
        Input contract:
        - position_snapshot_json: current on-platform state from backend
        - market_snapshot_json: fresh normalized market snapshot

        Expected position example:
        {
          "currentStrategy": "BALANCED",
          "currentProtocol": "aave-v3",
          "balanceUsd": 1250,
          "proofOfLifeOk": true,
          "withdrawalMode": "scheduled_income"
        }
        """
        position = json.loads(position_snapshot_json)
        market = json.loads(market_snapshot_json)

        combined = json.dumps(
            {
                "position": position,
                "market": market,
            },
            sort_keys=True,
            separators=(",", ":"),
        )

        task = """
You are monitoring an active retirement allocation.
Read the normalized input JSON and return ONLY minified JSON with this exact schema:
{
  "status":"HEALTHY|DEGRADED|REBALANCE|PAUSE",
  "nextAction":"KEEP|WATCH|REBALANCE|PAUSE_NEW_CONTRIBUTIONS",
  "targetStrategy":"CONSERVATIVE|BALANCED|GROWTH",
  "targetProtocol":"string",
  "reasonShort":"string"
}
"""

        criteria = """
- Output MUST be valid minified JSON and nothing else.
- status must be one of: HEALTHY, DEGRADED, REBALANCE, PAUSE.
- nextAction must be one of: KEEP, WATCH, REBALANCE, PAUSE_NEW_CONTRIBUTIONS.
- targetStrategy must be one of: CONSERVATIVE, BALANCED, GROWTH.
- targetProtocol must name one candidate from the market snapshot, unless nextAction is PAUSE_NEW_CONTRIBUTIONS.
- reasonShort must be short, factual, and tied to the given JSON.
- Do not invent trade execution details.
- If market conditions no longer match the current allocation/risk, choose REBALANCE.
- If data quality is weak or contradictory, prefer WATCH or PAUSE_NEW_CONTRIBUTIONS.
"""

        result = gl.eq_principle.prompt_non_comparative(
            lambda: combined,
            task=task,
            criteria=criteria,
        )

        self.monitoring_decisions[gl.message.sender_address] = result

    @gl.public.view
    def get_profile(self, address: str) -> str:
        result = self.profiles.get(Address(address), None)
        return "" if result is None else result

    @gl.public.view
    def get_allocation_decision(self, address: str) -> str:
        result = self.allocation_decisions.get(Address(address), None)
        if result is None:
            return '{"error":"NO_ALLOCATION_DECISION"}'
        return result

    @gl.public.view
    def get_monitoring_decision(self, address: str) -> str:
        result = self.monitoring_decisions.get(Address(address), None)
        if result is None:
            return '{"error":"NO_MONITORING_DECISION"}'
        return result

    @gl.public.view
    def has_allocation_decision(self, address: str) -> bool:
        return self.allocation_decisions.get(Address(address), None) is not None

    @gl.public.view
    def has_monitoring_decision(self, address: str) -> bool:
        return self.monitoring_decisions.get(Address(address), None) is not None

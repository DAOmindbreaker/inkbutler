"""
yield_manager.py — InkButler's core LangGraph decision graph.

Graph flow:
  load_state → check_revoked → gather_data → analyze (Claude) → decide → execute → sleep → loop

Run:
  python graphs/yield_manager.py --vault 0x... --owner 0x... --profile 1
"""
from __future__ import annotations
import os, sys, time, json
from typing import Literal

from langgraph.graph import StateGraph
from langchain_anthropic import ChatAnthropic
from langchain_core.messages import HumanMessage, SystemMessage
from dotenv import load_dotenv

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from memory.state import VaultAgentState, RiskProfile
from tools.tydro import (
    get_vault_account_data, get_reserve_apy,
    get_pending_rewards, get_gas_price_gwei, is_agent_revoked,
)
from tools.userop import (
    send_user_op, wait_for_userop,
    encode_claim_and_compound, encode_supply_from_vault,
)

load_dotenv()

POLL_INTERVAL_SECONDS = int(os.getenv("POLL_INTERVAL", "300"))
USDC_ADDRESS = os.getenv("TYDRO_USDC",   "0x0000000000000000000000000000000000000000")
USDC_ATOKEN  = os.getenv("TYDRO_AUSDC",  "0x0000000000000000000000000000000000000000")
REWARD_TOKEN = os.getenv("TYDRO_REWARD", "0x0000000000000000000000000000000000000000")

HF_SAFE = {
    RiskProfile.CONSERVATIVE: 2.5,
    RiskProfile.BALANCED:     1.8,
    RiskProfile.AGGRESSIVE:   1.4,
}

claude = ChatAnthropic(model="claude-sonnet-4-20250514", max_tokens=512)


# ── Nodes ──────────────────────────────────────────────────────────────────────

def load_state(state: VaultAgentState) -> VaultAgentState:
    return {**state, "error": None, "decision": None, "userop_hash": None,
            "tx_confirmed": False, "claude_analysis": None}

def check_revoked(state: VaultAgentState) -> VaultAgentState:
    return {**state, "agent_revoked": is_agent_revoked()}

def route_revoked(state: VaultAgentState) -> Literal["gather_data", "sleep"]:
    if state["agent_revoked"]:
        print("[agent] Revoked — sleeping.")
        return "sleep"
    return "gather_data"

def gather_data(state: VaultAgentState) -> VaultAgentState:
    try:
        account  = get_vault_account_data()
        usdc_apy = get_reserve_apy(USDC_ADDRESS)
        pending  = get_pending_rewards([USDC_ATOKEN])
        gas      = get_gas_price_gwei()
        return {
            **state,
            "positions": [{
                "asset":               "USDC",
                "asset_address":       USDC_ADDRESS,
                "supplied_usd":        account["total_collateral_usd"],
                "apy_current":         usdc_apy,
                "pending_rewards_usd": sum(pending.values()),
                "health_factor":       account["health_factor"],
            }],
            "eth_gas_price_gwei": gas,
        }
    except Exception as e:
        return {**state, "error": str(e)}

def route_data(state: VaultAgentState) -> Literal["analyze", "sleep"]:
    return "sleep" if state.get("error") else "analyze"

def analyze(state: VaultAgentState) -> VaultAgentState:
    system = SystemMessage(content=(
        "You are InkButler's yield AI. Manage a Tydro vault on Ink Chain. "
        "Reply ONLY with JSON: {action: compound|supply|idle|alert, reason: str, amount_usd?: number}. "
        "No markdown."
    ))
    user_msg = HumanMessage(content=json.dumps({
        "risk_profile":       state["risk_profile"].name,
        "positions":          state["positions"],
        "gas_gwei":           state["eth_gas_price_gwei"],
        "hf_safe_threshold":  HF_SAFE[state["risk_profile"]],
    }))
    try:
        resp = claude.invoke([system, user_msg])
        data = json.loads(resp.content.strip())
        return {
            **state,
            "claude_analysis": resp.content,
            "decision": {
                "action":          data.get("action", "idle"),
                "reason":          data.get("reason", ""),
                "target_asset":    USDC_ADDRESS,
                "amount_usd":      data.get("amount_usd"),
                "userop_calldata": None,
            },
        }
    except Exception as e:
        return {**state, "error": f"Claude error: {e}"}

def route_decision(state: VaultAgentState) -> Literal["execute", "sleep"]:
    if state.get("error") or not state.get("decision"):
        return "sleep"
    return "execute" if state["decision"]["action"] in ("compound", "supply") else "sleep"

def execute(state: VaultAgentState) -> VaultAgentState:
    action = state["decision"]["action"]
    try:
        if action == "compound":
            calldata = encode_claim_and_compound([USDC_ATOKEN], REWARD_TOKEN)
        elif action == "supply":
            amount_wei = int((state["decision"].get("amount_usd") or 100) * 10**6)
            calldata   = encode_supply_from_vault(USDC_ADDRESS, amount_wei)
        else:
            return {**state, "error": f"Unknown action: {action}"}

        op_hash = send_user_op(calldata)
        receipt = wait_for_userop(op_hash, timeout=120)
        print(f"[agent] {action} confirmed. tx: {receipt.get('receipt', {}).get('transactionHash')}")
        return {**state, "userop_hash": op_hash, "tx_confirmed": True,
                "last_action_at": int(time.time())}
    except Exception as e:
        return {**state, "error": f"Execution error: {e}"}

def sleep_node(state: VaultAgentState) -> VaultAgentState:
    cycle = state.get("cycle_count", 0) + 1
    if state.get("error"):
        print(f"[cycle {cycle}] error: {state['error']}")
    elif state.get("decision"):
        d = state["decision"]
        print(f"[cycle {cycle}] {d['action']} — {d['reason']}")
    else:
        print(f"[cycle {cycle}] idle")
    print(f"Sleeping {POLL_INTERVAL_SECONDS}s…\n")
    time.sleep(POLL_INTERVAL_SECONDS)
    return {**state, "cycle_count": cycle}


# ── Graph ──────────────────────────────────────────────────────────────────────

def build_graph():
    g = StateGraph(VaultAgentState)
    for name, fn in [
        ("load_state",    load_state),
        ("check_revoked", check_revoked),
        ("gather_data",   gather_data),
        ("analyze",       analyze),
        ("execute",       execute),
        ("sleep",         sleep_node),
    ]:
        g.add_node(name, fn)

    g.set_entry_point("load_state")
    g.add_edge("load_state",  "check_revoked")
    g.add_conditional_edges("check_revoked", route_revoked)
    g.add_conditional_edges("gather_data",   route_data)
    g.add_conditional_edges("analyze",       route_decision)
    g.add_edge("execute", "sleep")
    g.add_edge("sleep",   "load_state")
    return g.compile()


if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--vault",   required=True)
    p.add_argument("--owner",   required=True)
    p.add_argument("--profile", default=1, type=int, help="0/1/2")
    args = p.parse_args()

    initial: VaultAgentState = {
        "vault_address": args.vault, "owner_address": args.owner,
        "risk_profile": RiskProfile(args.profile), "agent_revoked": False,
        "positions": [], "markets": [], "eth_gas_price_gwei": 0.0,
        "block_number": 0, "claude_analysis": None, "decision": None,
        "userop_hash": None, "tx_confirmed": False, "error": None,
        "cycle_count": 0, "last_action_at": None, "messages": [],
    }
    print("[InkButler] Agent starting…")
    build_graph().invoke(initial)

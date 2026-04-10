# InkButler 🤖

> **Your AI butler, always putting your yield to work.**

InkButler is an autonomous AI yield & risk manager built on **Ink Chain** (Kraken's OP Stack L2), powered by a non-custodial **AgentVault** smart contract and a **LangGraph + Claude** AI agent that continuously optimizes positions in **Tydro** (Ink's Aave V3 fork).

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.26-blue)](https://soliditylang.org)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-orange)](https://book.getfoundry.sh)
[![Next.js](https://img.shields.io/badge/Frontend-Next.js%2015-black)](https://nextjs.org)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          USER (Browser)                             │
│              RainbowKit · Wagmi · Viem · Next.js 15                 │
└───────────────────────────┬─────────────────────────────────────────┘
                            │ deposit / set strategy / emergency exit
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        AgentVault.sol                               │
│  ┌──────────────┐  ┌─────────────┐  ┌──────────────────────────┐  │
│  │ Owner actions│  │  Timelock   │  │ Agent-only actions        │  │
│  │ deposit      │  │ 24h delay   │  │ supplyFromVault           │  │
│  │ emergencyExit│  │ agent swap  │  │ withdraw → owner          │  │
│  │ revokeAgent  │  │ asset list  │  │ claimRewards              │  │
│  └──────────────┘  └─────────────┘  │ claimAndCompound          │  │
│                                      └──────────────────────────┘  │
└──────────────┬──────────────────────────────────┬──────────────────┘
               │ supply / withdraw / compound       │ read positions
               ▼                                    ▼
┌──────────────────────────┐        ┌───────────────────────────────┐
│  Tydro (Aave V3 fork)    │        │   LangGraph AI Agent          │
│  IPool · IRewards        │        │   Claude API · ERC-4337 UOps  │
│  aTokens · APY data      │        └───────────────────────────────┘
└──────────────────────────┘
```

**Key design principles:**
- Agent has **zero access to funds** — can only call `supplyFromVault`, `withdraw` (to owner only), `claimRewards`, `claimAndCompound`
- Owner can **revoke agent instantly** — no delay on revocation
- Agent replacement requires a **24-hour timelock**
- All positions remain in the **owner's AgentVault** — never a shared pool

---

## Repository Structure

```
inkbutler/
├── contracts/                      # Foundry project
│   ├── src/
│   │   ├── AgentVault.sol          # Core vault (ERC-4337 compatible)
│   │   └── interfaces/
│   │       ├── IPool.sol           # Tydro / Aave V3 pool interface
│   │       └── IRewardsController.sol
│   ├── test/
│   │   └── AgentVault.t.sol        # Unit + access control + timelock tests
│   ├── script/
│   │   └── DeployAgentVault.s.sol
│   └── foundry.toml
│
├── frontend/                       # Next.js 15 App Router
│   ├── app/
│   │   ├── layout.tsx              # Root layout + Web3 providers
│   │   ├── page.tsx                # Landing page
│   │   ├── deposit/page.tsx        # Approve + deposit flow
│   │   ├── profile/page.tsx        # Risk strategy selector (3 profiles)
│   │   └── dashboard/page.tsx      # Vault stats + agent control panel
│   ├── components/
│   │   └── Navbar.tsx
│   ├── lib/
│   │   ├── wagmi.ts                # Ink chain defs + RainbowKit config
│   │   └── contracts.ts            # ABI + addresses
│   └── package.json
│
├── agent/                          # LangGraph AI agent (Python)
│   ├── graphs/
│   │   └── yield_manager.py        # Main decision graph
│   ├── tools/
│   │   ├── tydro.py                # Read positions, APY, health factor
│   │   └── userop.py               # Send UserOps via Alchemy Account Kit
│   └── memory/
│       └── state.py                # Agent state schema
│
├── .env.example
├── .gitignore
└── README.md
```

---

## How to Run

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Foundry | latest | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| Node.js | ≥ 22 | [nodejs.org](https://nodejs.org) |
| pnpm | ≥ 9 | `npm i -g pnpm` |
| Python | ≥ 3.11 | [python.org](https://python.org) |

---

### Step 1 — Clone & configure environment

```bash
git clone https://github.com/DAOmindbreaker/inkbutler
cd inkbutler
cp .env.example .env
# Fill in your values — see .env.example for full reference
```

---

### Step 2 — Smart Contracts

```bash
cd contracts

# Install Foundry dependencies
forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts --no-commit

# Compile
forge build

# Run full test suite
forge test -vvv

# Gas report
forge test --gas-report

# Deploy to Ink Sepolia
source ../.env
forge script script/DeployAgentVault.s.sol:DeployAgentVault \
  --rpc-url ink_sepolia \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  -vvvv

# Copy deployed address into .env → NEXT_PUBLIC_AGENT_VAULT_ADDRESS
```

---

### Step 3 — Frontend

```bash
cd ../frontend
pnpm install
pnpm dev
# → http://localhost:3000
```

---

### Step 4 — AI Agent

```bash
cd ../agent
python -m venv .venv && source .venv/bin/activate
pip install langgraph langchain-anthropic web3 python-dotenv
python graphs/yield_manager.py
# Agent polls Tydro every 5 minutes and submits UserOps as needed
```

---

## Configuration Reference

| Variable | Description |
|----------|-------------|
| `INK_SEPOLIA_RPC` | Ink Sepolia RPC endpoint |
| `PRIVATE_KEY` | Deployer EOA private key |
| `TYDRO_POOL` | Tydro IPool address on Ink |
| `TYDRO_REWARDS` | Tydro DefaultIncentivesController address |
| `AGENT_ADDRESS` | AI agent hot wallet address (signs UserOps) |
| `NEXT_PUBLIC_AGENT_VAULT_ADDRESS` | Deployed AgentVault address |
| `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID` | WalletConnect Cloud project ID |
| `ANTHROPIC_API_KEY` | Claude API key for LangGraph agent |
| `AGENT_PRIVATE_KEY` | Agent hot wallet private key |

---

## MVP Roadmap

### v0.1 — Foundation ✅ *(this release)*
- [x] `AgentVault.sol` with supply, withdraw, compound, 24h timelock, instant revoke
- [x] Foundry test suite — unit, access control, timelock, emergency paths
- [x] Next.js 15 frontend — deposit flow, 3-profile strategy selector, dashboard
- [x] RainbowKit + Wagmi + Viem configured for Ink Sepolia + Mainnet
- [x] LangGraph + Alchemy Account Kit agent scaffold

### v0.2 — Agent Intelligence 🔨
- [ ] Full LangGraph decision graph: poll → evaluate → act loop
- [ ] APY comparison across all active Tydro markets
- [ ] Health factor monitoring with conservative exit triggers
- [ ] Real-time dashboard events via Ponder indexing

### v0.3 — Multi-Asset & Leverage 📦
- [ ] WETH, wstETH, WBTC vault support
- [ ] Cross-asset rebalancing for Balanced/Aggressive profiles
- [ ] Borrow + loop strategy (Aggressive profile only)
- [ ] Slippage guard on compound swap path

### v0.4 — Production Mainnet 🚀
- [ ] Ink Mainnet deployment
- [ ] Third-party security audit
- [ ] Safe multisig owner support
- [ ] Historical yield chart (Recharts + Ponder)
- [ ] Telegram / email alert integration

---

## Security

- **Non-custodial by design.** The agent EOA cannot transfer funds to arbitrary addresses — only interact with the whitelisted Tydro contracts.
- **Instant revoke.** `revokeAgent()` has no timelock. One transaction pauses all agent activity.
- **24h timelock** on agent address changes prevents a compromised agent key from replacing itself.
- **Audit status:** Unaudited MVP. Do not use with significant funds before a formal audit.

---

## License

MIT © 2026 [DAOmindbreaker](https://github.com/DAOmindbreaker)

import { parseAbi } from "viem";

export const AGENT_VAULT_ADDRESS = (process.env.NEXT_PUBLIC_AGENT_VAULT_ADDRESS ?? "0x0000000000000000000000000000000000000000") as `0x${string}`;

export const agentVaultAbi = parseAbi([
  "function depositToVault(address asset, uint256 amount) external",
  "function emergencyWithdrawAll(address asset) external",
  "function revokeAgent() external",
  "function reinstateAgent() external",
  "function setRiskProfile(uint8 profile) external",
  "function cancelTimelock(bytes32 id) external",
  "function queueAgentUpdate(address newAgent) external returns (bytes32 id)",
  "function executeAgentUpdate(address newAgent, bytes32 id) external",
  "function supplyFromVault(address asset, uint256 amount) external",
  "function withdraw(address asset, uint256 amount) external returns (uint256)",
  "function claimRewards(address[] calldata assets) external returns (uint256)",
  "function owner() view returns (address)",
  "function agent() view returns (address)",
  "function riskProfile() view returns (uint8)",
  "function agentRevoked() view returns (bool)",
  "function allowedAssets(address) view returns (bool)",
]);

export const erc20Abi = parseAbi([
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function balanceOf(address account) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
]);

export const RISK_LABELS = ["Conservative", "Balanced", "Aggressive"] as const;

export const RISK_DESCRIPTIONS = {
  0: "Low volatility assets only. Capital preservation first.",
  1: "Mix of stable and growth assets. Moderate auto-compounding.",
  2: "Max yield hunting. Higher exposure, higher reward.",
} as const;

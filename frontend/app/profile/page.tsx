"use client";

import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { agentVaultAbi, AGENT_VAULT_ADDRESS, RISK_LABELS, RISK_DESCRIPTIONS } from "@/lib/contracts";
import { ConnectButton } from "@rainbow-me/rainbowkit";

const RISK_META = [
  { emoji: "🛡️", color: "#3b82f6" },
  { emoji: "⚖️", color: "#7cffd4" },
  { emoji: "🚀", color: "#f97316" },
] as const;

export default function ProfilePage() {
  const { address, isConnected } = useAccount();
  const { data: currentProfile } = useReadContract({
    address: AGENT_VAULT_ADDRESS, abi: agentVaultAbi, functionName: "riskProfile",
    query: { enabled: !!address },
  });
  const { writeContract, data: txHash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  if (!isConnected) return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "24px", paddingTop: "80px" }}>
      <p style={{ color: "#6b7280" }}>Connect your wallet to choose a strategy.</p>
      <ConnectButton />
    </div>
  );

  return (
    <div style={{ maxWidth: "672px", margin: "0 auto", paddingTop: "32px" }}>
      <h1 style={{ fontWeight: 700, fontSize: "1.875rem", marginBottom: "8px" }}>Strategy</h1>
      <p style={{ color: "#6b7280", fontSize: "0.875rem", marginBottom: "32px" }}>
        Choose how aggressive the AI should be when managing your yield.
      </p>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "16px" }}>
        {RISK_META.map(({ emoji, color }, i) => {
          const isActive = currentProfile === i;
          return (
            <button key={i} onClick={() => writeContract({ address: AGENT_VAULT_ADDRESS, abi: agentVaultAbi, functionName: "setRiskProfile", args: [i] })}
              disabled={isPending || isConfirming || isActive}
              style={{ background: isActive ? `${color}18` : "#0e1118", border: `2px solid ${isActive ? color : "#1c2130"}`, borderRadius: "16px", padding: "24px", textAlign: "left", cursor: isActive ? "default" : "pointer", transition: "border-color 0.2s" }}>
              <div style={{ fontSize: "2rem", marginBottom: "12px" }}>{emoji}</div>
              <div style={{ fontWeight: 700, fontSize: "0.875rem", color: isActive ? color : "#e8eaf0", marginBottom: "8px" }}>
                {RISK_LABELS[i as 0|1|2]}
                {isActive && <span style={{ marginLeft: "8px", fontSize: "0.7rem", opacity: 0.7 }}>active</span>}
              </div>
              <p style={{ fontSize: "0.75rem", color: "#6b7280", lineHeight: 1.6, margin: 0 }}>
                {RISK_DESCRIPTIONS[i as 0|1|2]}
              </p>
            </button>
          );
        })}
      </div>

      {isSuccess && <p style={{ color: "#7cffd4", fontSize: "0.875rem", fontFamily: "monospace", textAlign: "center", marginTop: "16px" }}>✓ Strategy updated</p>}
    </div>
  );
}

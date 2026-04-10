"use client";

import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { agentVaultAbi, AGENT_VAULT_ADDRESS, RISK_LABELS } from "@/lib/contracts";
import { ConnectButton } from "@rainbow-me/rainbowkit";

const USDC_ADDRESS = "0x0000000000000000000000000000000000000000" as `0x${string}`;

function StatCard({ label, value, unit, note }: { label: string; value: string; unit: string; note: string }) {
  return (
    <div className="card-glow" style={{ padding: "20px" }}>
      <div style={{ fontSize: "0.75rem", color: "#6b7280", marginBottom: "4px" }}>{label}</div>
      <div className="stat-value">{value} <span style={{ fontSize: "0.875rem", color: "#6b7280", fontFamily: "monospace" }}>{unit}</span></div>
      <div style={{ fontSize: "0.7rem", color: "#6b728066", fontFamily: "monospace", marginTop: "4px" }}>{note}</div>
    </div>
  );
}

export default function DashboardPage() {
  const { address, isConnected } = useAccount();
  const { data: agentRevoked } = useReadContract({ address: AGENT_VAULT_ADDRESS, abi: agentVaultAbi, functionName: "agentRevoked", query: { enabled: !!address } });
  const { data: riskProfile } = useReadContract({ address: AGENT_VAULT_ADDRESS, abi: agentVaultAbi, functionName: "riskProfile", query: { enabled: !!address } });
  const { data: agentAddress } = useReadContract({ address: AGENT_VAULT_ADDRESS, abi: agentVaultAbi, functionName: "agent", query: { enabled: !!address } });
  const { writeContract, data: txHash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  if (!isConnected) return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "24px", paddingTop: "80px" }}>
      <p style={{ color: "#6b7280" }}>Connect your wallet to view your dashboard.</p>
      <ConnectButton />
    </div>
  );

  return (
    <div style={{ paddingTop: "16px" }}>
      <h1 style={{ fontWeight: 700, fontSize: "1.875rem", marginBottom: "32px" }}>Dashboard</h1>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: "16px", marginBottom: "32px" }}>
        <StatCard label="Total Supplied" value="—" unit="USDC" note="Connect to Tydro subgraph" />
        <StatCard label="Pending Rewards" value="—" unit="TOKEN" note="Claim via agent cycle" />
        <StatCard label="Risk Strategy" value={riskProfile !== undefined ? RISK_LABELS[riskProfile as 0|1|2] : "—"} unit="" note="Change in Strategy tab" />
      </div>

      <div className="card-glow" style={{ padding: "24px", marginBottom: "16px" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "16px" }}>
          <h2 style={{ fontWeight: 600, margin: 0 }}>Agent Control</h2>
          <span style={{ fontSize: "0.75rem", fontFamily: "monospace", padding: "2px 10px", borderRadius: "999px", border: `1px solid ${agentRevoked ? "#ef444466" : "#7cffd466"}`, color: agentRevoked ? "#ef4444" : "#7cffd4", background: agentRevoked ? "#ef444418" : "#7cffd418" }}>
            {agentRevoked ? "REVOKED" : "ACTIVE"}
          </span>
        </div>
        <div style={{ fontFamily: "monospace", fontSize: "0.75rem", color: "#6b7280", marginBottom: "16px", wordBreak: "break-all" }}>
          Agent: {agentAddress ?? "loading..."}
        </div>
        {agentRevoked ? (
          <button onClick={() => writeContract({ address: AGENT_VAULT_ADDRESS, abi: agentVaultAbi, functionName: "reinstateAgent" })}
            disabled={isPending || isConfirming} className="btn-accent">
            {isPending || isConfirming ? "..." : "Reinstate Agent"}
          </button>
        ) : (
          <button onClick={() => writeContract({ address: AGENT_VAULT_ADDRESS, abi: agentVaultAbi, functionName: "revokeAgent" })}
            disabled={isPending || isConfirming} className="btn-danger">
            {isPending || isConfirming ? "..." : "Revoke Agent"}
          </button>
        )}
      </div>

      <div className="card-glow" style={{ padding: "24px", borderColor: "#ef444433", marginBottom: "16px" }}>
        <h2 style={{ fontWeight: 600, color: "#ef4444", marginBottom: "8px" }}>Emergency Withdraw</h2>
        <p style={{ fontSize: "0.75rem", color: "#6b7280", marginBottom: "16px" }}>
          Bypasses the agent and pulls all funds from Tydro back to your wallet immediately.
        </p>
        <button onClick={() => writeContract({ address: AGENT_VAULT_ADDRESS, abi: agentVaultAbi, functionName: "emergencyWithdrawAll", args: [USDC_ADDRESS] })}
          disabled={isPending || isConfirming} className="btn-danger">
          {isPending || isConfirming ? "Processing..." : "Withdraw All (Emergency)"}
        </button>
      </div>

      {isSuccess && <p style={{ color: "#7cffd4", fontSize: "0.875rem", fontFamily: "monospace", textAlign: "center" }}>✓ Transaction confirmed</p>}
    </div>
  );
}

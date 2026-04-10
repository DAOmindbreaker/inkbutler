"use client";

import { useState } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseUnits, formatUnits } from "viem";
import { agentVaultAbi, erc20Abi, AGENT_VAULT_ADDRESS } from "@/lib/contracts";
import { ConnectButton } from "@rainbow-me/rainbowkit";

const USDC_ADDRESS = "0x0000000000000000000000000000000000000000" as `0x${string}`;
const USDC_DECIMALS = 6;

export default function DepositPage() {
  const { address, isConnected } = useAccount();
  const [amount, setAmount] = useState("");

  const { data: allowance = 0n } = useReadContract({
    address: USDC_ADDRESS, abi: erc20Abi, functionName: "allowance",
    args: [address!, AGENT_VAULT_ADDRESS], query: { enabled: !!address },
  });

  const { data: usdcBalance = 0n } = useReadContract({
    address: USDC_ADDRESS, abi: erc20Abi, functionName: "balanceOf",
    args: [address!], query: { enabled: !!address },
  });

  const { writeContract, data: txHash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  const parsedAmount = amount ? parseUnits(amount, USDC_DECIMALS) : 0n;
  const needsApproval = parsedAmount > allowance;

  if (!isConnected) return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "24px", paddingTop: "80px" }}>
      <p style={{ color: "#6b7280" }}>Connect your wallet to deposit.</p>
      <ConnectButton />
    </div>
  );

  return (
    <div style={{ maxWidth: "448px", margin: "0 auto", paddingTop: "32px" }}>
      <h1 style={{ fontWeight: 700, fontSize: "1.875rem", marginBottom: "8px" }}>Deposit</h1>
      <p style={{ color: "#6b7280", fontSize: "0.875rem", marginBottom: "24px" }}>
        Tokens are held in your AgentVault. The AI agent supplies them to Tydro on your behalf.
      </p>

      <div className="card-glow" style={{ padding: "24px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.75rem", color: "#6b7280", marginBottom: "8px" }}>
          <span>Wallet USDC</span>
          <button onClick={() => setAmount(formatUnits(usdcBalance, USDC_DECIMALS))}
            style={{ background: "none", border: "none", color: "#6b7280", cursor: "pointer", fontSize: "0.75rem" }}>
            {formatUnits(usdcBalance, USDC_DECIMALS)} USDC → max
          </button>
        </div>

        <div style={{ position: "relative", marginBottom: "16px" }}>
          <input type="number" min="0" placeholder="0.00" value={amount}
            onChange={(e) => setAmount(e.target.value)}
            style={{ width: "100%", background: "#07090f", border: "1px solid #1c2130", borderRadius: "12px", padding: "12px 60px 12px 16px", fontSize: "1.25rem", fontFamily: "monospace", color: "#e8eaf0", outline: "none", boxSizing: "border-box" }} />
          <span style={{ position: "absolute", right: "16px", top: "50%", transform: "translateY(-50%)", color: "#6b7280", fontSize: "0.875rem" }}>USDC</span>
        </div>

        {needsApproval ? (
          <button onClick={() => writeContract({ address: USDC_ADDRESS, abi: erc20Abi, functionName: "approve", args: [AGENT_VAULT_ADDRESS, parsedAmount] })}
            disabled={!parsedAmount || isPending || isConfirming} className="btn-accent" style={{ width: "100%" }}>
            {isPending || isConfirming ? "Approving..." : "Approve USDC"}
          </button>
        ) : (
          <button onClick={() => writeContract({ address: AGENT_VAULT_ADDRESS, abi: agentVaultAbi, functionName: "depositToVault", args: [USDC_ADDRESS, parsedAmount] })}
            disabled={!parsedAmount || isPending || isConfirming} className="btn-accent" style={{ width: "100%" }}>
            {isPending || isConfirming ? "Depositing..." : "Deposit to Vault"}
          </button>
        )}

        {isSuccess && <p style={{ color: "#7cffd4", fontSize: "0.875rem", textAlign: "center", marginTop: "12px", fontFamily: "monospace" }}>✓ Transaction confirmed</p>}
      </div>
    </div>
  );
}

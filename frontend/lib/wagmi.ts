import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { defineChain } from "viem";

export const inkSepolia = defineChain({
  id: 763373,
  name: "Ink Sepolia",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: { http: [process.env.NEXT_PUBLIC_RPC_URL ?? "https://rpc-gel-sepolia.inkonchain.com"] },
  },
  blockExplorers: {
    default: { name: "Blockscout", url: "https://explorer-sepolia.inkonchain.com" },
  },
  testnet: true,
});

export const inkMainnet = defineChain({
  id: 57073,
  name: "Ink",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://rpc-gel.inkonchain.com"] },
  },
  blockExplorers: {
    default: { name: "Blockscout", url: "https://explorer.inkonchain.com" },
  },
});

export const wagmiConfig = getDefaultConfig({
  appName: "InkButler",
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID ?? "demo",
  chains: [inkSepolia, inkMainnet],
  ssr: true,
});

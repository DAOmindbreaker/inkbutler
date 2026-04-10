"use client";

import "@rainbow-me/rainbowkit/styles.css";
import "./globals.css";
import { RainbowKitProvider, darkTheme } from "@rainbow-me/rainbowkit";
import { WagmiProvider } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { wagmiConfig } from "@/lib/wagmi";
import { useState } from "react";
import Navbar from "@/components/Navbar";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());

  return (
    <html lang="en">
      <body style={{ background: "#07090f", color: "#e8eaf0", minHeight: "100vh" }}>
        <WagmiProvider config={wagmiConfig}>
          <QueryClientProvider client={queryClient}>
            <RainbowKitProvider theme={darkTheme({ accentColor: "#7CFFD4", accentColorForeground: "#0a0a0f" })}>
              <Navbar />
              <main style={{ maxWidth: "1152px", margin: "0 auto", padding: "96px 16px 64px" }}>
                {children}
              </main>
            </RainbowKitProvider>
          </QueryClientProvider>
        </WagmiProvider>
      </body>
    </html>
  );
}

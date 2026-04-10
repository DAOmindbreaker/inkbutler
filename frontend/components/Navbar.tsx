"use client";

import { ConnectButton } from "@rainbow-me/rainbowkit";
import Link from "next/link";
import { usePathname } from "next/navigation";

const navLinks = [
  { href: "/",          label: "Home"      },
  { href: "/deposit",   label: "Deposit"   },
  { href: "/profile",   label: "Strategy"  },
  { href: "/dashboard", label: "Dashboard" },
];

export default function Navbar() {
  const path = usePathname();

  return (
    <header style={{
      position: "fixed", top: 0, left: 0, right: 0, zIndex: 50,
      borderBottom: "1px solid #1c2130",
      background: "rgba(7,9,15,0.85)",
      backdropFilter: "blur(12px)",
    }}>
      <div style={{ maxWidth: "1152px", margin: "0 auto", padding: "0 16px", height: "64px", display: "flex", alignItems: "center", justifyContent: "space-between", gap: "24px" }}>
        <Link href="/" style={{ fontWeight: 800, fontSize: "1.125rem", textDecoration: "none", color: "#e8eaf0" }}>
          <span style={{ color: "#7cffd4" }}>Ink</span>Butler
        </Link>

        <nav style={{ display: "flex", gap: "4px" }}>
          {navLinks.map(({ href, label }) => (
            <Link key={href} href={href} style={{
              padding: "6px 12px", borderRadius: "8px", fontSize: "0.875rem",
              fontWeight: 500, textDecoration: "none",
              color: path === href ? "#7cffd4" : "#6b7280",
              background: path === href ? "rgba(124,255,212,0.1)" : "transparent",
            }}>
              {label}
            </Link>
          ))}
        </nav>

        <ConnectButton accountStatus="avatar" chainStatus="icon" showBalance={false} />
      </div>
    </header>
  );
}

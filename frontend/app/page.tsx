import Link from "next/link";

export default function HomePage() {
  return (
    <section style={{ display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center", gap: "32px", paddingTop: "64px" }}>
      <span style={{ display: "inline-flex", alignItems: "center", gap: "8px", padding: "4px 12px", borderRadius: "999px", border: "1px solid #1c2130", fontSize: "0.75rem", fontFamily: "monospace", color: "#6b7280" }}>
        <span style={{ width: "6px", height: "6px", borderRadius: "50%", background: "#7cffd4" }} />
        Live on Ink Sepolia
      </span>

      <div style={{ maxWidth: "768px" }}>
        <h1 style={{ fontWeight: 800, fontSize: "clamp(2.5rem, 6vw, 4.5rem)", lineHeight: 1, letterSpacing: "-0.02em", marginBottom: "16px" }}>
          Your AI yields,{" "}
          <span style={{ background: "linear-gradient(135deg, #7cffd4 0%, #4b96ff 100%)", WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent" }}>
            always working.
          </span>
        </h1>
        <p style={{ color: "#6b7280", fontSize: "1.125rem", maxWidth: "512px", margin: "0 auto" }}>
          InkButler autonomously manages your Tydro positions — supplying, compounding rewards,
          and rebalancing risk — 24/7. You keep the keys.
        </p>
      </div>

      <div style={{ display: "flex", gap: "16px", flexWrap: "wrap", justifyContent: "center" }}>
        <Link href="/deposit" style={{ background: "#7cffd4", color: "#07090f", fontWeight: 700, borderRadius: "10px", padding: "12px 24px", textDecoration: "none", fontSize: "1rem" }}>
          Start Earning →
        </Link>
        <a href="https://github.com/DAOmindbreaker/inkbutler" target="_blank" rel="noopener noreferrer"
          style={{ padding: "12px 24px", borderRadius: "10px", border: "1px solid #1c2130", color: "#6b7280", textDecoration: "none", fontSize: "1rem" }}>
          View Source
        </a>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: "16px", width: "100%", maxWidth: "672px", marginTop: "32px" }}>
        {[
          { icon: "🔒", title: "Non-custodial", body: "Agent can only interact with Tydro. Zero access to your funds directly." },
          { icon: "⏱️", title: "24h Timelock", body: "Any agent change requires a 24-hour delay. Revoke instantly if needed." },
          { icon: "🤖", title: "LangGraph AI", body: "Powered by Claude. Monitors APY, health factor, and auto-compounds rewards." },
        ].map(({ icon, title, body }) => (
          <div key={title} className="card-glow" style={{ padding: "20px", textAlign: "left" }}>
            <div style={{ fontSize: "1.5rem", marginBottom: "8px" }}>{icon}</div>
            <div style={{ fontWeight: 600, fontSize: "0.875rem", marginBottom: "4px" }}>{title}</div>
            <p style={{ fontSize: "0.75rem", color: "#6b7280", lineHeight: 1.6, margin: 0 }}>{body}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

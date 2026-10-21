import Sidebar from "@/components/layout/Sidebar";
export default function PartnersPage() {
  return (
    <div
      style={{
        minHeight: "100vh",
        display: "grid",
        gridTemplateColumns: "280px 1fr",
        background: "#f4f7f4",
        fontFamily: "Inter, sans-serif",
        color: "#153328",
      }}
    >
      <Sidebar active="partners" />

      <main
        style={{
          padding: "32px",
          background: "#f4f7f4",
          color: "#153328",
        }}
      >
        <section style={{ marginBottom: "24px" }}>
          <p
            style={{
              fontSize: "12px",
              fontWeight: 700,
              textTransform: "uppercase",
              letterSpacing: "0.08em",
              color: "#6b8075",
              marginBottom: "8px",
            }}
          >
            Partner
          </p>
          <h1 style={{ fontSize: "32px", margin: 0 }}>Partneranfragen</h1>
          <p style={{ color: "#6b8075", marginTop: "8px" }}>
            Übersicht über eingehende Partnerbedarfe und Umwandlung in neue Fälle.
          </p>
        </section>

        <section
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(3, minmax(0, 1fr))",
            gap: "16px",
            marginBottom: "24px",
          }}
        >
          <div
            style={{
              background: "white",
              borderRadius: "20px",
              padding: "20px",
              boxShadow: "0 10px 30px rgba(21,51,40,0.06)",
            }}
          >
            <p style={{ margin: 0, color: "#6b8075", fontSize: "14px" }}>Offen</p>
            <h2 style={{ margin: "8px 0 0", fontSize: "28px" }}>2</h2>
          </div>

          <div
            style={{
              background: "white",
              borderRadius: "20px",
              padding: "20px",
              boxShadow: "0 10px 30px rgba(21,51,40,0.06)",
            }}
          >
            <p style={{ margin: 0, color: "#6b8075", fontSize: "14px" }}>Heute dringend</p>
            <h2 style={{ margin: "8px 0 0", fontSize: "28px" }}>1</h2>
          </div>

          <div
            style={{
              background: "white",
              borderRadius: "20px",
              padding: "20px",
              boxShadow: "0 10px 30px rgba(21,51,40,0.06)",
            }}
          >
            <p style={{ margin: 0, color: "#6b8075", fontSize: "14px" }}>Umwandelbar</p>
            <h2 style={{ margin: "8px 0 0", fontSize: "28px" }}>2</h2>
          </div>
        </section>

        <section
          style={{
            display: "grid",
            gridTemplateColumns: "1.2fr 0.8fr",
            gap: "20px",
          }}
        >
          <div
            style={{
              background: "white",
              borderRadius: "24px",
              padding: "24px",
              boxShadow: "0 10px 30px rgba(21,51,40,0.06)",
            }}
          >
            <h3 style={{ marginTop: 0 }}>Anfragen</h3>

            <div
              style={{
                background: "#f6f8f6",
                borderRadius: "18px",
                padding: "18px",
                marginBottom: "14px",
              }}
            >
              <strong>Pflegezentrum Aareblick</strong>
              <p style={{ color: "#6b8075" }}>Seeland · Heute</p>
              <p>Ausfall Wohnbereich 2 · 2 Abendfenster offen</p>
            </div>

            <div
              style={{
                background: "#f6f8f6",
                borderRadius: "18px",
                padding: "18px",
              }}
            >
              <strong>Spital Region West</strong>
              <p style={{ color: "#6b8075" }}>Bern West · 48h</p>
              <p>2 Austritte mit Übergangspflege</p>
            </div>
          </div>

          <aside
            style={{
              background: "#16392d",
              color: "white",
              borderRadius: "24px",
              padding: "24px",
              boxShadow: "0 16px 40px rgba(21,51,40,0.18)",
            }}
          >
            <p
              style={{
                fontSize: "12px",
                textTransform: "uppercase",
                letterSpacing: "0.08em",
                color: "rgba(255,255,255,0.7)",
                marginTop: 0,
              }}
            >
              Anfrage Detail
            </p>

            <h2 style={{ marginTop: "8px" }}>Pflegezentrum Aareblick</h2>
            <p style={{ color: "rgba(255,255,255,0.75)" }}>Seeland · Heute</p>

            <div
              style={{
                background: "rgba(255,255,255,0.08)",
                borderRadius: "18px",
                padding: "16px",
                marginTop: "20px",
              }}
            >
              <strong>Bedarf</strong>
              <p style={{ color: "rgba(255,255,255,0.8)" }}>
                Ausfall Wohnbereich 2 · 2 Abendfenster offen
              </p>
            </div>

            <div
              style={{
                background: "rgba(255,255,255,0.08)",
                borderRadius: "18px",
                padding: "16px",
                marginTop: "12px",
              }}
            >
              <strong>Status</strong>
              <p style={{ color: "rgba(255,255,255,0.8)" }}>Bereit zur Umwandlung in Fall</p>
            </div>
          </aside>
        </section>
      </main>
    </div>
  );
}
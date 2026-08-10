export default function OperationsPage() {
  return (
    <main
      style={{
        padding: "32px",
        fontFamily: "Inter, sans-serif",
        background: "#f4f7f4",
        minHeight: "100vh",
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
          Operations
        </p>
        <h1 style={{ fontSize: "32px", margin: 0 }}>Navora Operations Board</h1>
        <p style={{ color: "#6b8075", marginTop: "8px" }}>
          Übersicht über neue Fälle, Teamprüfung und laufende Versorgung.
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
          <p style={{ margin: 0, color: "#6b8075", fontSize: "14px" }}>Neue Fälle</p>
          <h2 style={{ margin: "8px 0 0", fontSize: "28px" }}>3</h2>
        </div>

        <div
          style={{
            background: "white",
            borderRadius: "20px",
            padding: "20px",
            boxShadow: "0 10px 30px rgba(21,51,40,0.06)",
          }}
        >
          <p style={{ margin: 0, color: "#6b8075", fontSize: "14px" }}>In Teamprüfung</p>
          <h2 style={{ margin: "8px 0 0", fontSize: "28px" }}>3</h2>
        </div>

        <div
          style={{
            background: "white",
            borderRadius: "20px",
            padding: "20px",
            boxShadow: "0 10px 30px rgba(21,51,40,0.06)",
          }}
        >
          <p style={{ margin: 0, color: "#6b8075", fontSize: "14px" }}>Laufend</p>
          <h2 style={{ margin: "8px 0 0", fontSize: "28px" }}>2</h2>
        </div>
      </section>

      <section
        style={{
          display: "grid",
          gridTemplateColumns: "1.6fr 0.9fr",
          gap: "20px",
          alignItems: "start",
        }}
      >
        <section
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(3, minmax(0, 1fr))",
            gap: "16px",
          }}
        >
          <div
            style={{
              background: "#eef3ef",
              borderRadius: "24px",
              padding: "20px",
              minHeight: "320px",
            }}
          >
            <h3 style={{ marginTop: 0 }}>Neue Fälle</h3>

            <div
              style={{
                background: "white",
                borderRadius: "18px",
                padding: "16px",
                marginBottom: "12px",
                boxShadow: "0 8px 24px rgba(21,51,40,0.06)",
              }}
            >
              <strong>Anna Meier</strong>
              <p style={{ margin: "8px 0 0", color: "#6b8075" }}>Bern West · Heute</p>
            </div>

            <div
              style={{
                background: "white",
                borderRadius: "18px",
                padding: "16px",
                marginBottom: "12px",
                boxShadow: "0 8px 24px rgba(21,51,40,0.06)",
              }}
            >
              <strong>Ruth Keller</strong>
              <p style={{ margin: "8px 0 0", color: "#6b8075" }}>Seeland · 48h</p>
            </div>
          </div>

          <div
            style={{
              background: "#eef3ef",
              borderRadius: "24px",
              padding: "20px",
              minHeight: "320px",
            }}
          >
            <h3 style={{ marginTop: 0 }}>In Teamprüfung</h3>

            <div
              style={{
                background: "white",
                borderRadius: "18px",
                padding: "16px",
                marginBottom: "12px",
                boxShadow: "0 8px 24px rgba(21,51,40,0.06)",
              }}
            >
              <strong>Elsa Kunz</strong>
              <p style={{ margin: "8px 0 0", color: "#6b8075" }}>
                Bern West · Team Bern West
              </p>
            </div>

            <div
              style={{
                background: "white",
                borderRadius: "18px",
                padding: "16px",
                marginBottom: "12px",
                boxShadow: "0 8px 24px rgba(21,51,40,0.06)",
              }}
            >
              <strong>Clara Moser</strong>
              <p style={{ margin: "8px 0 0", color: "#6b8075" }}>
                Zürich Pilot · Team Zürich Pilot
              </p>
            </div>
          </div>

          <div
            style={{
              background: "#eef3ef",
              borderRadius: "24px",
              padding: "20px",
              minHeight: "320px",
            }}
          >
            <h3 style={{ marginTop: 0 }}>Laufend</h3>

            <div
              style={{
                background: "white",
                borderRadius: "18px",
                padding: "16px",
                marginBottom: "12px",
                boxShadow: "0 8px 24px rgba(21,51,40,0.06)",
              }}
            >
              <strong>Lina Berger</strong>
              <p style={{ margin: "8px 0 0", color: "#6b8075" }}>Seeland · laufend</p>
            </div>

            <div
              style={{
                background: "white",
                borderRadius: "18px",
                padding: "16px",
                marginBottom: "12px",
                boxShadow: "0 8px 24px rgba(21,51,40,0.06)",
              }}
            >
              <strong>Hugo Frei</strong>
              <p style={{ margin: "8px 0 0", color: "#6b8075" }}>Bern West · laufend</p>
            </div>
          </div>
        </section>

        <aside
          style={{
            background: "#16392d",
            color: "white",
            borderRadius: "24px",
            padding: "24px",
            minHeight: "320px",
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
            Case Detail
          </p>

          <h2 style={{ marginTop: "8px" }}>Anna Meier</h2>
          <p style={{ color: "rgba(255,255,255,0.75)" }}>CH2301 · Bern West</p>

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
              Morgenpflege, Medikation, Tochter informieren
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
            <p style={{ color: "rgba(255,255,255,0.8)" }}>Neuaufnahme · heute priorisiert</p>
          </div>

          <div
            style={{
              background: "rgba(255,255,255,0.08)",
              borderRadius: "18px",
              padding: "16px",
              marginTop: "12px",
            }}
          >
            <strong>Team</strong>
            <p style={{ color: "rgba(255,255,255,0.8)" }}>Noch offen</p>
          </div>
        </aside>
      </section>
    </main>
  );
}
import React from "react";
import "./app.css";

/** ---------- Small UI helpers ---------- */

type CardProps = { title: string; text: string };
const Card: React.FC<CardProps> = ({ title, text }) => (
  <article className="card">
    <h3>{title}</h3>
    <p>{text}</p>
  </article>
);

type StatProps = { label: string; value: string };
const Stat: React.FC<StatProps> = ({ label, value }) => (
  <div className="stat">
    <div className="stat-value">{value}</div>
    <div className="stat-label">{label}</div>
  </div>
);

const Pill: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <span className="pill">{children}</span>
);

/** ---------- Page ---------- */

export default function App() {
  return (
    <main className="app" id="top">
      {/* Header */}
      <header className="header" role="banner">
        <div className="container row between center-v">
          <a className="brand" href="#top" aria-label="Project Aether home">
            <div className="dot" />
            <span>Project Aether</span>
          </a>
          <nav className="nav" aria-label="Primary">
            <a href="#overview">Overview</a>
            <a href="#features">Features</a>
            <a href="#how">How it works</a>
            <a href="#api">API</a>
            <a href="#team">Team</a>
          </nav>
        </div>
      </header>

      {/* Hero */}
      <section className="section hero" aria-label="Hero">
        <div className="container grid-hero">
          <div className="hero-text">
            <h1>
              The unseen system that keeps{" "}
              <span className="accent">space logistics</span> findable.
            </h1>
            <p className="lead">
              Aether is an offline-first inventory platform for the Gateway Deep
              Space Logistics Module. It tracks items, containers, and movements
              across missions — reliably, on the local network, with clean
              contracts and fast lookups.
            </p>
            <div className="cta">
              <a
                className="btn primary"
                href="/openapi.json"
                aria-label="Download OpenAPI"
              >
                Download OpenAPI
              </a>
              <a className="btn" href="#demo" aria-label="Jump to demo section">
                Watch Demo
              </a>
            </div>
            <div className="hero-pills">
              <Pill>Offline-first</Pill>
              <Pill>Deterministic schemas</Pill>
              <Pill>Edge validated</Pill>
              <Pill>Time-ordered UUIDv7</Pill>
            </div>
          </div>
          <div className="hero-art">
            <div className="orb">
              <div className="orb-sm" />
            </div>
          </div>
        </div>
      </section>

      {/* Quick stats */}
      <section className="section shade" aria-label="Stats">
        <div className="container row between wrap">
          <Stat label="Nested containers" value="≤ 5 levels" />
          <Stat label="Event throughput (edge)" value="1k+/s" />
          <Stat label="Cold-start validation" value="&lt; 20ms" />
          <Stat label="Schema drift" value="0 by design" />
        </div>
      </section>

      {/* Overview (non-technical) */}
      <section id="overview" className="section" aria-label="Overview">
        <div className="container grid-two">
          <div>
            <h2 className="section-title">What Aether is</h2>
            <p>
              Aether is the shared source of truth for where things are. Every
              item and container (CTB) is tagged; kiosks record check-ins,
              check-outs, moves, and returns; and the system answers the most
              important question quickly: <em>“Where is it right now?”</em>
            </p>
            <p>
              It’s built to operate without the cloud. Kiosks and clients run on
              the same LAN, validate requests locally, and sync
              opportunistically. Data stays consistent through strict contracts
              and idempotent events.
            </p>
          </div>
          <div>
            <h2 className="section-title">Why it matters</h2>
            <p>
              In constrained environments, time and context are scarce. Aether
              removes guesswork: crews can locate, stage, and audit inventory in
              seconds, not hours — even when disconnected from Earth.
            </p>
          </div>
        </div>
      </section>

      {/* Feature grid */}
      <section id="features" className="section" aria-label="Features">
        <div className="container">
          <h2 className="section-title">Capabilities</h2>
          <div className="grid-features">
            <Card
              title="Structured Entities"
              text="Items, CTBs, tags, zones — each with strict, versioned JSON Schemas."
            />
            <Card
              title="Event Ledger"
              text="Bind, unbind, check-in/out, move, return — all idempotent and time-ordered."
            />
            <Card
              title="Placement Index"
              text="Fast read-model for “where is X?” with nesting up to 5 levels."
            />
            <Card
              title="Offline-First"
              text="Operates on LAN; queues and replays when links are down."
            />
            <Card
              title="Strong Validation"
              text="AJV at the edge; OpenAPI 3.1 for the network contract."
            />
            <Card
              title="Observability"
              text="Deterministic outcomes, clear error codes, and backpressure hints."
            />
          </div>
        </div>
      </section>

      {/* How it works: technical + non-technical */}
      <section id="how" className="section shade" aria-label="How it works">
        <div className="container grid-two">
          <div>
            <h2 className="section-title">How it works (at a glance)</h2>
            <ul className="bullets">
              <li>Tag items and CTBs; scan them at kiosks.</li>
              <li>
                Each action becomes a validated event (e.g., CHECKIN, MOVE).
              </li>
              <li>Events update a placement index for instant lookups.</li>
              <li>Everything works on the local network; sync is optional.</li>
            </ul>
          </div>
          <div>
            <h2 className="section-title">Under the hood</h2>
            <ul className="bullets">
              <li>
                <strong>Schemas:</strong> Common primitives + entities + events
                (JSON Schema 2020-12).
              </li>
              <li>
                <strong>Contracts:</strong> OpenAPI 3.1; request/response bodies
                reference the same schemas.
              </li>
              <li>
                <strong>Identity:</strong> UUIDv7 for time-ordering; idempotency
                via <code>eventKey</code>.
              </li>
              <li>
                <strong>Validation:</strong> AJV with formats; fixtures gate
                every change.
              </li>
              <li>
                <strong>Read model:</strong> “Placement” snapshot materialized
                from the event stream.
              </li>
              <li>
                <strong>Backpressure:</strong> 429s with{" "}
                <code>Retry-After</code> and per-event verdicts.
              </li>
            </ul>
          </div>
        </div>
      </section>

      {/* API */}
      <section id="api" className="section" aria-label="API and contracts">
        <div className="container">
          <h2 className="section-title">API & Contracts</h2>
          <div className="grid-features">
            <Card
              title="Ingress"
              text="POST /api/ops/events — submit batched event envelopes with device metadata."
            />
            <Card
              title="Queries"
              text="GET /api/read/placement/:type/:id — constant-time lookup for where an object is."
            />
            <Card
              title="Schemas"
              text="Single source of truth. Entities, events, and ops reuse common definitions."
            />
            <Card
              title="Tooling"
              text="Redocly lint, swagger bundle, AJV fixture tests, and a LAN mock server."
            />
          </div>
          <div className="cta" style={{ marginTop: "1rem" }}>
            <a className="btn primary" href="/openapi.json">
              Download OpenAPI
            </a>
            <a className="btn" href="#fixtures">
              Browse Test Fixtures
            </a>
          </div>
        </div>
      </section>

      {/* Team */}
      <section id="team" className="section shade" aria-label="Team">
        <div className="container">
          <h2 className="section-title">Team</h2>
          <div className="team">
            <div className="avatar">
              <div className="img" />
              <span>Max Moyle</span>
            </div>
            <div className="avatar">
              <div className="img" />
              <span>Benjamin Lu</span>
            </div>
            <div className="avatar">
              <div className="img" />
              <span>Josue Collado</span>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="footer" role="contentinfo">
        <div className="container">
          <small>
            © {new Date().getFullYear()} Project Aether • NASA HUNCH ·{" "}
            <a href="#top">Back to top</a>
          </small>
        </div>
      </footer>
    </main>
  );
}

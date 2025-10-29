// App.tsx
import React from "react";
import "./app.css";

/** ---------- Small UI helpers ---------- */

type CardProps = { title: string; children: React.ReactNode };
const Card: React.FC<CardProps> = ({ title, children }) => (
  <article className="card">
    <h3>{title}</h3>
    <div className="card-body">{children}</div>
  </article>
);

const Pill: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <span className="pill">{children}</span>
);

type BadgeProps = { state: "done" | "wip" | "todo"; label: string };
const Badge: React.FC<BadgeProps> = ({ state, label }) => (
  <span className={`badge ${state}`}>
    <span className="dot" aria-hidden /> {label}
  </span>
);

const KBD: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <kbd className="kbd">{children}</kbd>
);

const MonoBlock: React.FC<{ children: React.ReactNode; label?: string }> = ({
  children,
  label,
}) => (
  <figure className="mono">
    {label && <figcaption>{label}</figcaption>}
    <pre>
      <code>{children}</code>
    </pre>
  </figure>
);

/** ---------- Page ---------- */

export default function App() {
  return (
    <main className="app" id="top">
      {/* Header */}
      <header className="header" role="banner">
        <div className="container row between center-v">
          <a className="brand" href="#top" aria-label="DLSM IMS home">
            <div className="dot" />
            <span>DLSM Inventory • NASA HUNCH</span>
          </a>
          <nav className="nav" aria-label="Primary">
            <a href="#now">What exists</a>
            <a href="#arch">Architecture</a>
            <a href="#data">Data model</a>
            <a href="#api">API</a>
            <a href="#dev">Dev workflow</a>
            <a href="#team">Team</a>
          </nav>
        </div>
      </header>

      {/* Hero */}
      <section className="section hero" aria-label="Hero">
        <div className="container grid-hero">
          <div className="hero-text">
            <h1>
              Offline-first inventory for the{" "}
              <span className="accent">Deep Space Logistics Module</span>.
            </h1>
            <p className="lead">
              This is our current, working prototype. It runs on a LAN,
              validates events at the edge against shared JSON Schemas, and
              maintains a fast read model for <em>“where is X right now?”</em>{" "}
              We built it schema-first, with fixtures guarding every change.
            </p>
            <div className="hero-pills">
              <Pill>Schema-first</Pill>
              <Pill>Event-sourced</Pill>
              <Pill>UUIDv7</Pill>
              <Pill>LAN-only demo</Pill>
            </div>
          </div>
          <div className="hero-art">
            <div className="orb">
              <div className="orb-sm" />
            </div>
          </div>
        </div>
      </section>

      {/* Now: concrete status */}
      <section id="now" className="section shade" aria-label="What exists">
        <div className="container">
          <h2 className="section-title">What exists right now</h2>

          <div className="grid-features">
            <Card title="Contracts & Validation">
              <ul className="bullets">
                <li>
                  <Badge state="done" label="Ready" /> OpenAPI 3.1 network
                  contract referencing shared schemas.
                </li>
                <li>
                  <Badge state="done" label="Ready" /> JSON Schema 2020-12
                  (entities, events, primitives).
                </li>
                <li>
                  <Badge state="done" label="Ready" /> AJV validation at kiosks
                  and server ingress.
                </li>
              </ul>
            </Card>

            <Card title="Event Ledger & Read Model">
              <ul className="bullets">
                <li>
                  <Badge state="done" label="Ready" /> Idempotent envelopes with{" "}
                  <code>eventKey</code> and UUIDv7 IDs.
                </li>
                <li>
                  <Badge state="done" label="Ready" /> Materialized{" "}
                  <code>placement</code> index (nested ≤ 5 levels).
                </li>
                <li>
                  <Badge state="wip" label="WIP" /> Reconciliation & audits.
                </li>
              </ul>
            </Card>

            <Card title="Kiosk & Devices">
              <ul className="bullets">
                <li>
                  <Badge state="done" label="Ready" /> LAN-first kiosk UI
                  (scan/submit/check placement).
                </li>
                <li>
                  <Badge state="wip" label="WIP" /> RFID reader integration on
                  Raspberry Pi.
                </li>
                <li>
                  <Badge state="wip" label="WIP" /> Background sync queue.
                </li>
              </ul>
            </Card>

            <Card title="Operations">
              <ul className="bullets">
                <li>
                  <Badge state="done" label="Ready" /> Fixture suite covering
                  entities/events & failure cases.
                </li>
                <li>
                  <Badge state="done" label="Ready" /> Bundled{" "}
                  <code>openapi.json</code> for local inspection.
                </li>
                <li>
                  <Badge state="todo" label="Next" /> Metrics pipeline & trace
                  IDs.
                </li>
              </ul>
            </Card>
          </div>
        </div>
      </section>

      {/* Architecture */}
      <section id="arch" className="section" aria-label="Architecture">
        <div className="container grid-two">
          <div>
            <h2 className="section-title">How it works (end-to-end)</h2>
            <ol className="steps">
              <li>
                <strong>Scan.</strong> Kiosk reads Item + CTB tags, operator
                selects the action.
              </li>
              <li>
                <strong>Validate at the edge.</strong> Payload validated with
                AJV against shared schemas.
              </li>
              <li>
                <strong>Ingress.</strong> Batched, idempotent events POST to the
                server on the same LAN.
              </li>
              <li>
                <strong>Apply.</strong> Server verifies order (UUIDv7), stores
                in ledger, updates <code>placement</code>.
              </li>
              <li>
                <strong>Query.</strong> Clients hit constant-time placement
                lookups.
              </li>
            </ol>

            <ul className="bullets tight">
              <li>
                Backpressure: 429 + <code>Retry-After</code> with per-event
                verdicts.
              </li>
              <li>
                Determinism: same inputs → same outcomes; all ops are
                idempotent.
              </li>
            </ul>
          </div>

          <div>
            <Card title="Example ingress (batched)">
              <MonoBlock label="POST /api/ops/events">
                {`{
  "device": {"id":"kiosk-01","model":"rpi"},
  "events": [
    {
      "id":"0192f5e8-3f2a-7c3b-b1e2-8a8d1b25c901",
      "eventKey":"bind:item-123@ctb-42",
      "type":"BIND",
      "at":"2025-10-28T20:11:32.541Z",
      "actor":"op-17",
      "data":{"itemId":"item-123","containerId":"ctb-42"}
    }
  ]
}`}
              </MonoBlock>
            </Card>
          </div>
        </div>
      </section>

      {/* Data model */}
      <section id="data" className="section shade" aria-label="Data model">
        <div className="container grid-two">
          <div>
            <h2 className="section-title">Entities & Events</h2>
            <div className="grid-features">
              <Card title="Entities">
                <ul className="bullets">
                  <li>
                    <strong>Item</strong> — unique tagged asset.
                  </li>
                  <li>
                    <strong>Container (CTB)</strong> — can nest (≤ 5).
                  </li>
                  <li>
                    <strong>Zone</strong> — location/site context.
                  </li>
                  <li>
                    <strong>Tag</strong> — RFID/barcode metadata.
                  </li>
                </ul>
              </Card>
              <Card title="Event types">
                <ul className="bullets">
                  <li>BIND / UNBIND</li>
                  <li>CHECKIN / CHECKOUT</li>
                  <li>MOVE / RETURN</li>
                  <li>RECONCILE (WIP)</li>
                </ul>
              </Card>
            </div>
          </div>

          <div>
            <Card title="Item schema (excerpt)">
              <MonoBlock label="JSON Schema 2020-12">
                {`{
  "$id": "schemas/entities/item.json",
  "type": "object",
  "required": ["id","tag","name"],
  "properties": {
    "id": {"type":"string", "pattern":"^item-"},
    "name": {"type":"string", "minLength": 1},
    "tag": {
      "type":"object",
      "required":["type","value"],
      "properties":{
        "type":{"enum":["rfid","barcode"]},
        "value":{"type":"string"}
      }
    }
  },
  "additionalProperties": false
}`}
              </MonoBlock>
            </Card>
          </div>
        </div>
      </section>

      {/* API (only what we actually have) */}
      <section id="api" className="section" aria-label="API">
        <div className="container">
          <h2 className="section-title">API (implemented today)</h2>
          <div className="table">
            <div className="thead">
              <div>Method</div>
              <div>Path</div>
              <div>Purpose</div>
              <div>Status</div>
            </div>
            <div className="trow">
              <div>
                <KBD>POST</KBD>
              </div>
              <div>
                <code>/api/ops/events</code>
              </div>
              <div>Submit batched, idempotent events</div>
              <div>
                <Badge state="done" label="Ready" />
              </div>
            </div>
            <div className="trow">
              <div>
                <KBD>GET</KBD>
              </div>
              <div>
                <code>/api/read/placement/:type/:id</code>
              </div>
              <div>Constant-time “where is X?”</div>
              <div>
                <Badge state="done" label="Ready" />
              </div>
            </div>
            <div className="trow">
              <div>
                <KBD>GET</KBD>
              </div>
              <div>
                <code>/openapi.json</code>
              </div>
              <div>Bundled contract (local server)</div>
              <div>
                <Badge state="done" label="Ready" />
              </div>
            </div>
          </div>

          <MonoBlock label="Curl examples (local dev)">
            {`# Post a batch
curl -sS http://localhost:5173/api/ops/events \\
  -H "Content-Type: application/json" \\
  -d @fixtures/ops/bind.json

# Lookup placement for an item
curl -sS http://localhost:5173/api/read/placement/item/item-123 | jq`}
          </MonoBlock>
        </div>
      </section>

      {/* Dev workflow */}
      <section id="dev" className="section shade" aria-label="Dev workflow">
        <div className="container grid-two">
          <div>
            <h2 className="section-title">How we develop</h2>
            <ol className="steps">
              <li>Edit a schema → run fixtures → expect red/green.</li>
              <li>
                Bundle <code>openapi.json</code> → validate references.
              </li>
              <li>Start LAN mock server → hit with kiosk & curl.</li>
              <li>Verify placement read model and failure paths.</li>
            </ol>
          </div>
          <div>
            <Card title="Scripts we actually run">
              <MonoBlock>
                {`npm run openapi:lint      # redocly lint shared/openapi/*.yaml
npm run openapi:bundle    # swagger-cli bundle -> dist/openapi.json
npm run fixtures:all      # AJV fixture suite (entities/events/ops)
npm run dev:server        # start LAN mock + read-model`}
              </MonoBlock>
              <p className="muted">
                Tip (Windows PowerShell): if scripts are blocked, set an
                appropriate <code>ExecutionPolicy</code> for your scope.
              </p>
            </Card>
          </div>
        </div>
      </section>

      {/* Team */}
      <section id="team" className="section" aria-label="Team">
        <div className="container">
          <h2 className="section-title">Team</h2>
          <div className="team">
            <div className="avatar">
              <div className="img">
                <div
                  style={{
                    width: 100,
                    height: 100,
                    borderRadius: "50%",
                    overflow: "hidden",
                    position: "relative",
                  }}
                >
                  <img
                    src="/max.jpg"
                    alt="Max Moyle"
                    style={{
                      position: "absolute",
                      width: "200%",
                      height: "200%",
                      left: "-50%",
                      top: "-7%",
                      objectFit: "cover",
                      transform: "translateY(6px)",
                      transformOrigin: "center",
                      display: "block",
                    }}
                  />
                </div>
              </div>
              <span>Max Moyle</span>
            </div>

            <div className="avatar">
              <div className="img">
                <div
                  style={{
                    width: 100,
                    height: 100,
                    borderRadius: "50%",
                    overflow: "hidden",
                    position: "relative",
                  }}
                >
                  <img
                    src="/ben.jpg"
                    alt="Benjamin Lu"
                    style={{
                      position: "absolute",
                      width: "125%",
                      height: "125%",
                      left: "-10%",
                      top: "-6%",
                      objectFit: "cover",
                      transform: "translateY(6px)",
                      transformOrigin: "center",
                      display: "block",
                    }}
                  />
                </div>
              </div>
              <span>Benjamin Lu</span>
            </div>

            <div className="avatar">
              <div className="img">
                <div
                  style={{
                    width: 100,
                    height: 100,
                    borderRadius: "50%",
                    overflow: "hidden",
                    position: "relative",
                  }}
                >
                  <img
                    src="/josh.png"
                    alt="Josue Collado"
                    style={{
                      position: "absolute",
                      width: "200%",
                      height: "200%",
                      left: "-50%",
                      top: "-7%",
                      objectFit: "cover",
                      transform: "translateY(6px)",
                      transformOrigin: "center",
                      display: "block",
                    }}
                  />
                </div>
              </div>
              <span>Josue Collado</span>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="footer" role="contentinfo">
        <div className="container">
          <small>
            © {new Date().getFullYear()} DLSM Inventory • NASA HUNCH ·{" "}
            <a href="#top">Back to top</a>
          </small>
        </div>
      </footer>
    </main>
  );
}

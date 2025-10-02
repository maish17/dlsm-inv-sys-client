import "dotenv/config";
import Fastify from "fastify";
import { Pool } from "pg";

const app = Fastify({
  logger: { transport: { target: "pino-pretty" } },
});

const pool = new Pool({
  host: process.env.PGHOST ?? "localhost",
  port: Number(process.env.PGPORT ?? 5432),
  user: process.env.PGUSER ?? "aether",
  password: process.env.PGPASSWORD ?? "aether",
  database: process.env.PGDATABASE ?? "aether",
});

// --- helpers -------------------------------------------------------
const q = (text, params = []) => pool.query(text, params);

app.get("/healthz", async () => ({ ok: true }));

// GET all meals in a blob by RFID (ordered by slot)
app.get("/api/blobs/:rfid/meals", async (req, rep) => {
  const { rfid } = req.params;
  const sql = `
    SELECT m.meal_id, b.blob_id, m.slot,
           m.meal_type_code, mt.kind AS meal_kind, mt.label AS meal_label,
           m.is_special, m.expiration_date, m.status,
           mt.energy_kcal, mt.vit_a_mcg_rae,
           mt.vit_b2_mg, mt.vit_b3_mg, mt.vit_b4_mg, mt.vit_b5_mg, mt.vit_b6_mg,
           mt.vit_b7_mg, mt.vit_b8_mg, mt.vit_b9_mg, mt.vit_b10_mg, mt.vit_b11_mg, mt.vit_b12_mg,
           m.created_at, m.updated_at
      FROM aether.blobs b
      JOIN aether.meals m       ON m.blob_id = b.blob_id
      JOIN aether.meal_types mt ON mt.code   = m.meal_type_code
     WHERE b.rfid = $1
     ORDER BY m.slot;
  `;
  const { rows } = await q(sql, [rfid]);
  if (rows.length === 0) return rep.code(404).send({ error: "NOT_FOUND" });
  return rows;
});

// PUT update a specific meal (by rfid + slot)
app.put("/api/blobs/:rfid/meals/:slot", async (req, rep) => {
  const { rfid, slot } = req.params;
  const body = req.body ?? {};

  // Accept a small set of fields
  const fields = {};
  if (body.meal_type_code !== undefined)
    fields.meal_type_code = Number(body.meal_type_code);
  if (body.is_special !== undefined)
    fields.is_special = Boolean(body.is_special);
  if (body.expiration_date !== undefined)
    fields.expiration_date = body.expiration_date; // 'YYYY-MM-DD'
  if (body.status !== undefined) fields.status = String(body.status); // e.g., 'FRESH'/'EXPIRED'/'USED'

  const keys = Object.keys(fields);
  if (keys.length === 0) return rep.code(400).send({ error: "NO_FIELDS" });

  // Build dynamic UPDATE
  const sets = keys.map((k, i) => `${k} = $${i + 1}`).join(", ");
  const params = keys.map((k) => fields[k]);

  const sql = `
    WITH target AS (
      SELECT blob_id FROM aether.blobs WHERE rfid = $${params.length + 1}
    )
    UPDATE aether.meals m
       SET ${sets}, updated_at = now()
      FROM target t
     WHERE m.blob_id = t.blob_id AND m.slot = $${params.length + 2}
     RETURNING m.*;
  `;
  const { rows } = await q(sql, [...params, rfid, Number(slot)]);
  if (rows.length === 0) return rep.code(404).send({ error: "NOT_FOUND" });
  return rows[0];
});

// POST create/register a blob
app.post("/api/blobs", async (req, rep) => {
  const { rfid, slot_count = 4 } = req.body ?? {};
  if (!rfid || typeof rfid !== "string") {
    return rep.code(400).send({ error: "BAD_RFID" });
  }
  const { rows } = await q(
    `INSERT INTO aether.blobs (rfid, slot_count, status)
     VALUES ($1, $2, 'ACTIVE')
     ON CONFLICT (rfid) DO NOTHING
     RETURNING blob_id, rfid, slot_count, status, created_at, updated_at;`,
    [rfid, Number(slot_count)]
  );
  if (rows.length === 0) return rep.code(200).send({ info: "EXISTS" });
  return rows[0];
});

// bootstrap
const port = Number(process.env.PORT ?? 8080);
app
  .listen({ port, host: "0.0.0.0" })
  .then(() => app.log.info(`API listening on http://localhost:${port}`))
  .catch((err) => {
    app.log.error(err);
    process.exit(1);
  });

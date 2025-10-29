// services/edge-server/src/server.mjs
import Fastify from "fastify";
import { Pool } from "pg";
import dotenv from "dotenv";

dotenv.config();
const logPretty = process.env.NODE_ENV !== "production";
const fastify = Fastify({
  logger: logPretty ? { transport: { target: "pino-pretty" } } : true,
});

// --- Postgres pool ---
const pool = new Pool({
  host: process.env.PGHOST || "127.0.0.1",
  port: Number(process.env.PGPORT || 5432),
  user: process.env.PGUSER || "aether",
  password: process.env.PGPASSWORD || "aether",
  database: process.env.PGDATABASE || "aether",
});

async function q(text, params = []) {
  const client = await pool.connect();
  try {
    return await client.query(text, params);
  } finally {
    client.release();
  }
}

// --- Routes ---

// Health (also checks DB)
fastify.get("/health", async () => {
  const r = await q("SELECT 1 as ok");
  return { ok: true, db: r.rows[0].ok === 1, time: new Date().toISOString() };
});

// Item details + inferred subtype + owner
fastify.get("/api/read/item/:id", async (req, reply) => {
  const { id } = req.params;
  const sql = `
    SELECT
      i.item_id, i.rfid, i.name, i.description, i.size_m3, i.mass_kg,
      i.status::text AS status, i.site_id, i.user_id, i.created_at, i.updated_at,
      u.full_name AS owner_name,
      CASE
        WHEN c.item_id  IS NOT NULL THEN 'CLOTHES'
        WHEN se.item_id IS NOT NULL THEN 'SCIENTIFIC_EQUIPMENT'
        WHEN sp.item_id IS NOT NULL THEN 'SPARE_PART'
        WHEN ms.item_id IS NOT NULL THEN 'MEDICAL_SUPPLY'
        WHEN hi.item_id IS NOT NULL THEN 'HYGIENE_ITEM'
        WHEN wc.item_id IS NOT NULL THEN 'WASTE_CONTAINER'
        WHEN b.blob_id  IS NOT NULL THEN 'CTB'
        ELSE 'GENERIC'
      END AS subtype
    FROM aether.items i
    LEFT JOIN aether.users u                ON u.user_id = i.user_id
    LEFT JOIN aether.blobs b                ON b.blob_id = i.item_id
    LEFT JOIN aether.clothes c              ON c.item_id = i.item_id
    LEFT JOIN aether.scientific_equipment se ON se.item_id = i.item_id
    LEFT JOIN aether.spare_parts sp         ON sp.item_id = i.item_id
    LEFT JOIN aether.medical_supplies ms    ON ms.item_id = i.item_id
    LEFT JOIN aether.hygiene_items hi       ON hi.item_id = i.item_id
    LEFT JOIN aether.waste_containers wc    ON wc.item_id = i.item_id
    WHERE i.item_id = $1
    LIMIT 1;
  `;
  const r = await q(sql, [id]);
  if (r.rowCount === 0) return reply.code(404).send({ error: "NOT_FOUND" });
  return r.rows[0];
});

// Effective location for an item (walk up container chain to outermost CTB/site)
fastify.get("/api/read/item/:id/location", async (req, reply) => {
  const { id } = req.params;
  const sql = `
    WITH RECURSIVE chain AS (
      SELECT i.item_id, i.site_id, 0 AS lvl
      FROM aether.items i
      WHERE i.item_id = $1
      UNION ALL
      SELECT parent_i.item_id, parent_i.site_id, c.lvl + 1
      FROM chain c
      JOIN aether.ctb_contents cc   ON cc.child_item_id = c.item_id
      JOIN aether.blobs pb          ON pb.blob_id = cc.parent_blob_id
      JOIN aether.items parent_i    ON parent_i.item_id = pb.blob_id
    )
    SELECT s.rack, s.shelf, s.depth
    FROM chain ch
    JOIN aether.storage_sites s ON s.site_id = ch.site_id
    ORDER BY ch.lvl DESC
    LIMIT 1;
  `;
  const r = await q(sql, [id]);
  if (r.rowCount === 0) return reply.code(404).send({ error: "NOT_FOUND" });
  return { itemId: id, location: r.rows[0] };
});

// CTB slots view: list all slots with meal occupancies
fastify.get("/api/read/ctb/:id/slots", async (req, reply) => {
  const { id } = req.params;
  const meta = await q(
    `SELECT blob_id, slot_count FROM aether.blobs WHERE blob_id = $1`,
    [id]
  );
  if (meta.rowCount === 0) return reply.code(404).send({ error: "NOT_FOUND" });

  const { slot_count } = meta.rows[0];
  const meals = await q(
    `
    SELECT m.slot, m.meal_id, m.status::text AS status,
           m.expiration_date, m.meal_type_code, mt.kind::text AS meal_kind, mt.label
    FROM aether.meals m
    LEFT JOIN aether.meal_types mt ON mt.code = m.meal_type_code
    WHERE m.blob_id = $1
    `,
    [id]
  );

  // build full slot map 1..slot_count
  const bySlot = new Map(meals.rows.map((r) => [r.slot, r]));
  const slots = Array.from({ length: slot_count }, (_, i) => {
    const s = i + 1;
    const meal = bySlot.get(s);
    return {
      slot: s,
      occupied: !!meal,
      meal: meal || null,
    };
  });

  return { ctbId: id, slotCount: slot_count, slots };
});

// --- start ---
const PORT = Number(process.env.PORT || 8080);
fastify
  .listen({ port: PORT, host: "0.0.0.0" })
  .then((addr) => fastify.log.info(`Edge server listening on ${addr}`))
  .catch((err) => {
    fastify.log.error(err);
    process.exit(1);
  });

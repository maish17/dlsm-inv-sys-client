// dev-server/server.mjs
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { URL, pathToFileURL } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

/* ===== AJV bootstrap: load every schema under a file:// $id ===== */

const SCHEMA_ROOT = path.resolve("shared/schemas");
const ajv = new Ajv2020({ strict: true, allErrors: true });
addFormats(ajv);

const readJson = (file) => JSON.parse(fs.readFileSync(file, "utf8"));

const listJsonFiles = (dir) =>
  fs
    .readdirSync(dir, { withFileTypes: true })
    .flatMap((e) => {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) return listJsonFiles(p);
      return e.isFile() && e.name.endsWith(".json") ? [p] : [];
    })
    .sort();

const fileToId = new Map();
for (const file of listJsonFiles(SCHEMA_ROOT)) {
  const schema = readJson(file);
  const id = pathToFileURL(path.resolve(file)).href; // base-URI for relative $ref
  ajv.addSchema(schema, id);
  fileToId.set(file, id);
}

// Compile request/response validators
const reqId = fileToId.get(
  path.join(SCHEMA_ROOT, "ops", "event-batch-request.json")
);
const resId = fileToId.get(
  path.join(SCHEMA_ROOT, "ops", "event-batch-response.json")
);
const validateRequest = ajv.compile({ $ref: reqId });
const validateResponse = ajv.compile({ $ref: resId });

/* ===== Minimal in-memory projector ===== */

const bindings = new Map(); // tagUid -> { target: 'OBJECT'|'ZONE', objectType?, objectId?, zoneId? }
const placements = new Map(); // "ITEM:uuid" -> { zoneId? | ctbPath?, updatedAt }
const transactions = new Map(); // txId -> { objectType, objectId, status, checkoutAt, expectedReturnAt?, returnedAt? }
const openTxByObject = new Map(); // "ITEM:uuid" -> txId
const seenEventKeys = new Set(); // idempotency across batches

const keyFor = (type, id) => `${type}:${id}`;

function applyEvent(ev) {
  const { kind, payload, producedAt } = ev;
  const now = producedAt ?? new Date().toISOString();

  switch (kind) {
    case "BIND": {
      // payload oneOf: tagUid + (objectType+objectId) | (zoneId)
      if (payload.objectType && payload.objectId) {
        bindings.set(payload.tagUid, {
          target: "OBJECT",
          objectType: payload.objectType,
          objectId: payload.objectId,
        });
      } else if (payload.zoneId) {
        bindings.set(payload.tagUid, {
          target: "ZONE",
          zoneId: payload.zoneId,
        });
      }
      return { status: "ACCEPTED" };
    }
    case "UNBIND": {
      bindings.delete(payload.tagUid);
      return { status: "ACCEPTED" };
    }
    case "CHECKIN": {
      const { objectType, objectId, zoneId, ctbPath } = payload;
      const k = keyFor(objectType, objectId);
      if (zoneId) placements.set(k, { zoneId, updatedAt: now });
      else if (ctbPath) placements.set(k, { ctbPath, updatedAt: now });
      return { status: "ACCEPTED" };
    }
    case "MOVE": {
      const { objectType, objectId, toZoneId, toCtbPath } = payload;
      const k = keyFor(objectType, objectId);
      if (toZoneId) placements.set(k, { zoneId: toZoneId, updatedAt: now });
      else if (toCtbPath)
        placements.set(k, { ctbPath: toCtbPath, updatedAt: now });
      return { status: "ACCEPTED" };
    }
    case "CHECKOUT": {
      const { objectType, objectId, expectedReturnAt } = payload;
      const txId = ev.eventId; // deterministic for mock
      const k = keyFor(objectType, objectId);
      transactions.set(txId, {
        objectType,
        objectId,
        status: "OPEN",
        checkoutAt: now,
        expectedReturnAt,
      });
      openTxByObject.set(k, txId);
      return { status: "ACCEPTED" };
    }
    case "RETURN": {
      const { txId, objectType, objectId } = payload;
      let id = txId;
      if (!id && objectType && objectId)
        id = openTxByObject.get(keyFor(objectType, objectId));
      const tx = id ? transactions.get(id) : null;
      if (tx && tx.status === "OPEN") {
        tx.status = "RETURNED";
        tx.returnedAt = now;
        openTxByObject.delete(keyFor(tx.objectType, tx.objectId));
      }
      return { status: "ACCEPTED" };
    }
    default:
      return {
        status: "REJECTED",
        code: "SCHEMA_INVALID",
        message: "Unknown kind",
      };
  }
}

/* ===== HTTP helpers ===== */

const JSON_CT = "application/json; charset=utf-8";
function sendJson(res, status, body) {
  const buf = Buffer.from(JSON.stringify(body));
  res.writeHead(status, {
    "content-type": JSON_CT,
    "content-length": buf.length,
  });
  res.end(buf);
}

function sendInvalid(res, details) {
  sendJson(res, 400, { error: "SCHEMA_INVALID", details });
}

async function readJsonBody(req, limitBytes = 512 * 1024) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on("data", (c) => {
      size += c.length;
      if (size > limitBytes) {
        reject(new Error("PAYLOAD_TOO_LARGE"));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on("end", () => {
      try {
        const text = Buffer.concat(chunks).toString("utf8");
        resolve(text ? JSON.parse(text) : {});
      } catch (e) {
        reject(new Error("INVALID_JSON"));
      }
    });
    req.on("error", reject);
  });
}

/* ===== Server ===== */

const server = http.createServer(async (req, res) => {
  const start = Date.now();
  const url = new URL(req.url || "/", "http://localhost");
  const method = req.method || "GET";

  try {
    // Health
    if (method === "GET" && url.pathname === "/health") {
      return sendJson(res, 200, { ok: true, time: new Date().toISOString() });
    }

    // POST /api/ops/events
    if (method === "POST" && url.pathname === "/api/ops/events") {
      let body;
      try {
        body = await readJsonBody(req);
      } catch (e) {
        const code = e.message;
        return sendJson(res, 400, { error: code });
      }

      if (!validateRequest(body)) {
        return sendInvalid(res, validateRequest.errors);
      }

      const { events = [], seqStart } = body;

      const results = [];
      let rejected = 0;
      let duplicate = 0;

      const batchSeen = new Set(); // prevent intra-batch duplicates

      events.forEach((ev, idx) => {
        const { eventId, eventKey } = ev;

        if (batchSeen.has(eventKey) || seenEventKeys.has(eventKey)) {
          results.push({
            eventId,
            eventKey,
            status: "DUPLICATE",
            eventIndex: idx,
          });
          duplicate++;
          return;
        }

        const out = applyEvent(ev);
        if (out.status === "ACCEPTED") {
          results.push({
            eventId,
            eventKey,
            status: "ACCEPTED",
            eventIndex: idx,
          });
          batchSeen.add(eventKey);
          seenEventKeys.add(eventKey);
        } else {
          results.push({
            eventId,
            eventKey,
            status: "REJECTED",
            code: out.code || "SCHEMA_INVALID",
            message: out.message || "Rejected by projector",
            eventIndex: idx,
          });
          rejected++;
        }
      });

      const response = {
        serverTime: new Date().toISOString(),
        ...(typeof seqStart === "number"
          ? { nextSeqExpected: seqStart + events.length }
          : {}),
        rejected,
        duplicate,
        results,
      };

      // Contract self-check: response must match schema
      if (!validateResponse(response)) {
        return sendJson(res, 500, {
          error: "SERVER_RESPONSE_INVALID",
          details: validateResponse.errors,
        });
      }

      return sendJson(res, 200, response);
    }

    // GET /api/read/binding/:tagUid
    if (method === "GET" && url.pathname.startsWith("/api/read/binding/")) {
      const tagUid = decodeURIComponent(url.pathname.split("/").pop() || "");
      const b = bindings.get(tagUid);
      return b
        ? sendJson(res, 200, { tagUid, ...b })
        : sendJson(res, 404, { error: "NOT_FOUND" });
    }

    // GET /api/read/placement/:type/:id
    if (method === "GET" && url.pathname.startsWith("/api/read/placement/")) {
      const [, , , , type, id] = url.pathname.split("/");
      const p = placements.get(keyFor(type, id));
      return p
        ? sendJson(res, 200, { objectType: type, objectId: id, ...p })
        : sendJson(res, 404, { error: "NOT_FOUND" });
    }

    // GET /api/read/tx/:txId
    if (method === "GET" && url.pathname.startsWith("/api/read/tx/")) {
      const txId = decodeURIComponent(url.pathname.split("/").pop() || "");
      const t = transactions.get(txId);
      return t
        ? sendJson(res, 200, { txId, ...t })
        : sendJson(res, 404, { error: "NOT_FOUND" });
    }

    return sendJson(res, 404, { error: "NOT_FOUND" });
  } catch (err) {
    console.error("Unhandled error:", err?.message ?? err);
    return sendJson(res, 500, { error: "INTERNAL_ERROR" });
  } finally {
    // one-line access log
    const ms = Date.now() - start;
    console.log(`${method} ${url.pathname} ${res.statusCode} ${ms}ms`);
  }
});

const PORT = Number(process.env.PORT || 8080);
server.listen(PORT, () => {
  console.log(`Mock server listening on http://localhost:${PORT}`);
});

// scripts/compile-schemas.mjs
import fs from "node:fs";
import path from "node:path";
import Ajv from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const ajv = new Ajv({ strict: true, allErrors: true });
addFormats(ajv);

// preload common by its $id (https://mission.schemas/v1/common.json)
const common = JSON.parse(
  fs.readFileSync("shared/schemas/defs/common.json", "utf8")
);
ajv.addSchema(common);

const dir = "shared/schemas/entities";
const files = fs
  .readdirSync(dir)
  .filter((f) => f.endsWith(".json"))
  .sort();

let errors = 0;
for (const f of files) {
  const p = path.join(dir, f);
  try {
    ajv.compile(JSON.parse(fs.readFileSync(p, "utf8")));
    console.log(`✓ ${p} is valid`);
  } catch (e) {
    errors++;
    console.error(`✗ ${p} invalid`);
    console.error(e?.message ?? e);
  }
}
process.exit(errors === 0 ? 0 : 1);

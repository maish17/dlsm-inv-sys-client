import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const SCHEMA_ROOT = path.resolve("shared/schemas");

const ajv = new Ajv2020({ strict: true, allErrors: true });
addFormats(ajv);

const readJson = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const rel = (p) => path.relative(process.cwd(), p);

const collectJsonFiles = (dir) => {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  return entries
    .flatMap((e) => {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) return collectJsonFiles(p);
      return e.isFile() && p.endsWith(".json") ? [p] : [];
    })
    .sort();
};

const files = collectJsonFiles(SCHEMA_ROOT);
const fileId = new Map();

let loadFailures = 0;
for (const file of files) {
  try {
    const schema = readJson(file);
    const id = pathToFileURL(path.resolve(file)).href;
    ajv.addSchema(schema, id);
    fileId.set(file, id);
  } catch (err) {
    loadFailures++;
    console.error(`✗ unreadable schema: ${rel(file)}`);
    console.error(err?.message ?? err);
  }
}

let compiledOk = 0;
let compiledFail = 0;

for (const dir of ["entities", "events", "ops"]) {
  const abs = path.join(SCHEMA_ROOT, dir);
  for (const file of collectJsonFiles(abs)) {
    const id = fileId.get(file);
    try {
      ajv.compile({ $ref: id });
      console.log(`✓ ${rel(file)} is valid`);
      compiledOk++;
    } catch (err) {
      compiledFail++;
      console.error(`✗ ${rel(file)} invalid`);
      console.error(err?.message ?? err);
    }
  }
}

if (compiledFail || loadFailures) {
  console.log(
    `\nSummary: ${compiledOk} passed, ${compiledFail} failed` +
      (loadFailures ? `, ${loadFailures} unreadable.` : ".")
  );
  process.exit(1);
} else {
  console.log(`\nSummary: ALL PASSED (${compiledOk} files).`);
  process.exit(0);
}

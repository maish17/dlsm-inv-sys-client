import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const SCHEMA_ROOT = path.resolve("shared/schemas");
const OK_DIR = path.resolve("tests/fixtures/ok");
const BAD_DIR = path.resolve("tests/fixtures/bad");

const ajv = new Ajv2020({ strict: true, allErrors: true });
addFormats(ajv);

const readJson = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const rel = (p) => path.relative(process.cwd(), p);

const collectJsonFiles = (dir) => {
  if (!fs.existsSync(dir)) return [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  return entries
    .flatMap((e) => {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) return collectJsonFiles(p);
      return e.isFile() && p.endsWith(".json") ? [p] : [];
    })
    .sort();
};

const printErrors = (errors = []) =>
  errors
    .map((e) => {
      const where = e.instancePath || "/";
      const msg = e.message || "validation error";
      return ` - at ${where}: ${msg}`;
    })
    .join("\n");

const fileToId = new Map();
let preloadFailures = 0;

for (const file of collectJsonFiles(SCHEMA_ROOT)) {
  try {
    const schema = readJson(file);
    if (schema.$id) delete schema.$id;
    const id = pathToFileURL(path.resolve(file)).href;
    ajv.addSchema(schema, id);
    fileToId.set(file, id);
  } catch (err) {
    preloadFailures++;
    console.error(`Unreadable schema: ${rel(file)}`);
    console.error(err?.message ?? err);
  }
}
if (preloadFailures) process.exit(1);

const reqPath = path.join(SCHEMA_ROOT, "ops", "event-batch-request.json");
const reqId = fileToId.get(reqPath);
let validate;
try {
  validate = ajv.compile({ $ref: reqId });
} catch (err) {
  console.error(`Could not compile: ${rel(reqPath)}`);
  console.error(err?.message ?? err);
  process.exit(1);
}

let okPassed = 0;
let okFailed = 0;
let badPassed = 0; // shouldn't pass
let badFailed = 0;

const validateFile = (file, expectValid) => {
  const data = readJson(file);
  const ok = validate(data);
  if (expectValid) {
    if (!ok) {
      okFailed++;
      console.error(`OK fixture failed: ${rel(file)}!`);
      console.error(printErrors(validate.errors));
      return 1;
    }
    okPassed++;
    console.log(`OK fixture passed: ${rel(file)}`);
    return 0;
  } else {
    if (ok) {
      badPassed++;
      console.error(`BAD fixture passed: ${rel(file)}!`);
      return 1;
    }
    badFailed++;
    console.log(`BAD fixture failed: ${rel(file)}`);
    return 0;
  }
};

let totalFailures = 0;
for (const f of collectJsonFiles(OK_DIR))
  totalFailures += validateFile(f, true);
for (const f of collectJsonFiles(BAD_DIR))
  totalFailures += validateFile(f, false);

if (totalFailures) {
  console.log(
    `\nSummary: ${okPassed} OK passed, ${okFailed} OK failed; ` +
      `${badFailed} BAD rejected, ${badPassed} BAD passed (should fail).`
  );
  process.exit(1);
} else {
  console.log(`\nSummary: ALL PASSED (${okPassed} OK, ${badFailed} BAD).`);
  process.exit(0);
}

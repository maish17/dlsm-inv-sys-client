# Schema Governance v1.0

**Scope.** Governs all **JSON Schemas** for the Mission Inventory System (API requests/responses, events, domain objects). Establishes **authoritative format, naming, units, required/optional rules, validation posture, versioning, security classification, verification, and change control**. Configuration-controlled.

**Normative language.** **MUST / SHOULD / MAY** as per RFC 2119.  
**WWND principles.** Safety • Determinism • Simplicity • Offline/DTN Tolerance • Traceability • Least Privilege • Observability • Graceful Degradation.

---

## 1) Source of Truth & Provenance

- **Canonical format:** JSON Schema **draft-2020-12** (**MUST** include `$schema`).
- **Stable identity:** Each schema **MUST** include a stable `$id` URI in a controlled namespace (e.g., `https://mission.schemas/v1/item.json`).
- **Single set version:** All schemas are versioned **together** (one SemVer for the set) to prevent drift.
- **Consumers:** Server/API **MUST** validate at runtime against these schemas; clients **MUST** generate types from the **same artifacts** (no ad-hoc duplicates).
- **Provenance:** Schemas **SHOULD** include `$comment` with author, change summary, and requirement/ICD references.

---

## 2) Naming & Conventions

- **JSON property names:** `camelCase` (**MUST**). Arrays use plural nouns (`items`).
- **Enum values:** `UPPER_SNAKE` (**MUST**) e.g., `OPEN`, `RETURNED`.
- **Identifiers:** `id`, `objectId`, `zoneId`, `containerId`, `tagId` used consistently.
- **Booleans:** positive form (e.g., `consumable: true|false`).
- **Timestamps:** `*At` suffix; **UTC RFC3339/ISO-8601** with `Z` (e.g., `2025-09-09T16:00:00Z`) with up to millisecond precision.
- **Codes:** `zoneCode` canonical uppercase segmented (e.g., `A1-B2-L1-BinA`).
- **Tag UID:** uppercase hex, no separators; length policy documented per tag technology.

---

## 3) Types, Required/Optional, and Data Hygiene

- **IDs:** UUID **v7** preferred (ULID permitted where stated); treat as **opaque**.
- **Numbers:** counts as integers; **quantities stored as base-unit integers** (see §4). `NaN`/`±∞` invalid. Decimal inputs use `.` and no grouping separators.
- **Nullability:** absence ≠ null; use explicit `nullable` (via `type`/`oneOf`) where permitted.
- **Required:** only when the operation/entity is invalid without it; optional fields MUST have clear “absent” semantics (no hidden defaults).
- **Strings:** UTF-8; inputs SHOULD be NFC-normalized; leading/trailing whitespace invalid unless specified.

---

## 4) Units (SI-First, Unambiguous)

- **Base storage units (MUST):** Mass **g**, Nutrition **µg** (integers), Distance **m**, Temperature **°C**.
- **Input acceptance:** Alternate units MAY be accepted only where explicitly defined; API **MUST** convert to base and **MUST** return base.
- **Rounding:** Conversion method/precision **MUST** be documented; silent or lossy coercion is **forbidden**.
- **No inference:** Ambiguous units are **rejected**.

---

## 5) Enums (Closed Sets)

- Enums are **closed**; unknown values **MUST** be rejected.
- Add value = **MINOR**; rename/remove value = **MAJOR** (deprecate per §9).
- If anticipating future values, an explicit `UNKNOWN` member MAY be added (still a closed set).

---

## 6) Validation Posture (Fail-Closed)

- **Unknown/extra fields:** **rejected** (`additionalProperties: false` by default). Exceptions MUST be documented per schema (Annex A).
- **Type coercion:** **disabled**.
- **Formats enforced:** UUID, timestamp, hex, URI; invalid formats **rejected**.
- **Normalization:** ONLY where specified (e.g., uppercase `tagUid`); occurs **pre-validation** and is documented.

---

## 7) Events: Idempotency, Ordering, and Time (DTN-Aware)

- **`eventKey`:** Every event **MUST** include a globally unique key (recommended: `deviceCode + epochMs + seq`). Exact duplicates → `IDEMPOTENT_REPLAY` (reject).
- **Per-device sequence:** **MUST** be monotonic; older-than-last events are **rejected** or **quarantined** per ops policy (documented).
- **Time bounds:** Device `timestamp` MUST be within **±5 minutes** of server; else `CLOCK_SKEW`. Server records authoritative `ingestedAt`.
- **Batch semantics:** **All-or-nothing** apply; per-event errors with stable codes and JSON Pointer paths; never partial silent drops.
- **Limits:** A single batch **MUST NOT** exceed **5 000 events** or **5 MB**, whichever hits first (to bound memory and latency).

---

## 8) Versioning (SemVer for the Entire Set)

- **MAJOR:** breaking (remove/rename fields; tighten required; incompatible semantics).
- **MINOR:** backward-compatible additions (new **optional** fields; new enum values).
- **PATCH:** non-functional fixes (typos, descriptions).
- The set carries **one** version; every bump appears in CHANGELOG with rationale & migration notes.

---

## 9) Deprecation & Compatibility

- Breaking changes require a **deprecation window** ≥ **one MINOR** where old and new are both accepted with warnings/telemetry.
- Removal in the next **MAJOR** only.
- Each deprecation MUST include: notice, migration steps, examples, target removal version, and telemetry to measure remaining usage.

---

## 10) Security, Privacy, Least Privilege

- **Classification:** Every field annotated via `x-classification`: **Public**, **Internal**, or **Sensitive** (Annex B).
- **Sensitive** fields never appear in logs/examples/mocks; API enforces redaction.
- **Retention:** Per-field `x-retention` annotation (**e.g.,** `mission`, `untilTxClose`, `90d`, `…`) guides purge/export; ops must implement.
- **Indexability:** `x-indexable: true|false` signals whether a field may be used for search indexes (avoid accidental PII indexing).
- Responses MUST reflect least-privilege: clients receive only role-appropriate fields (distinct response schemas if needed).
- No secrets/credentials in schemas/examples.

---

## 11) Observability & Error Contract

- Validation failures return `{ code, message, path?, details? }` using a shared, stable taxonomy (Annex E). `path` MUST be a JSON Pointer.
- Metrics MUST count rejects by `code`, unknown-enum attempts, clock-skew rejects; include labels `schema_version`, `client_id`, `device_code`.
- Minimal valid **examples** in each schema (used by mocks) MUST validate.

---

## 12) Verification & CI Gates

- Schemas MUST validate against the **meta-schema**; examples MUST validate against their schemas.
- CI MUST run a **compatibility classifier** (MAJOR/MINOR/PATCH) on schema diffs.
- Generated **TypeScript types** MUST compile; consumers MUST NOT define governed entities ad-hoc.
- PRs MUST attach diffed artifacts (schema + generated types) for reviewer inspection.
- **Contract tests:** For each request schema, CI MUST run example payloads through the validator in strict mode.

---

## 13) Change Control (WWND Checklist)

Before merge:

1. **Problem & Requirements** (with requirement/ICD IDs).
2. **Impact Analysis** (clients/services; migration; ops).
3. **Compatibility Class** (MAJOR/MINOR/PATCH) with rationale.
4. **Docs Updated** (schema descriptions; ICD cross-refs).
5. **Examples Updated** (and validated).
6. **Validation Posture** re-checked (`additionalProperties`, formats, required/optional).
7. **Observability** (error codes, metrics/alerts).
8. **Security Review** (classification, retention, indexability; least privilege).
9. **Approvals** (domain owner + security reviewer; QA as applicable).

**DoD:** Meta-schema + example validation pass; version bumped; CHANGELOG updated; CI green; sign-offs recorded.

---

## Annex A — Strictness Matrix (Normative)

| Artifact type           | `additionalProperties` | Notes                                                                         |
| ----------------------- | ---------------------- | ----------------------------------------------------------------------------- |
| **Requests (all)**      | **false**              | Fail-closed; unknown fields rejected.                                         |
| **Events (ingress)**    | **false**              | Idempotent & ordered; strict formats.                                         |
| **Responses (read)**    | false (default)        | MAY be true **only** when documented for forward-compat and covered by tests. |
| **Admin exports**       | true (by exception)    | Operator tooling; must be documented and version-stamped.                     |
| **Telemetry envelopes** | true (namespaced)      | Only inside `extensions` (Annex D).                                           |

---

## Annex B — Field Classification & Retention (Normative)

- **Public:** Safe for broad consumption (e.g., names, labels).
- **Internal:** Operational but non-sensitive (e.g., `ingestedAt`, internal IDs).
- **Sensitive:** PII, auth/security-relevant, or mission-critical; never logged/exposed to unauthorized clients.

Annotations:

- `x-classification: Public|Internal|Sensitive`
- `x-retention: mission|untilTxClose|90d|…`
- `x-indexable: true|false`

---

## Annex C — Schema Reuse & Referencing (Normative)

- Common primitives/enums **MUST** live under a shared `$id` (e.g., `https://mission.schemas/v1/$defs/common.json`) and be referenced with `$ref`.
- Cross-schema references **MUST** use absolute `$id` URIs; relative `$ref` only within a single document.
- Shared `$defs` **MUST** be stable; moving or renaming a `$def` is a **MAJOR** change.
- Avoid untyped “`metadata`” bags. If extensibility is required, use `extensions` (Annex D) or a **typed** `metadata` with explicit keys and `additionalProperties: false`.

---

## Annex D — Extensions & Forward-Compatibility (Normative)

- Vendor or experiment fields **MUST** live under a dedicated `extensions` object with `additionalProperties: true`.
- Extension keys **MUST** be namespaced: `x-<org>-<feature>` (e.g., `x-nasa-ops`).
- Extensions **MUST NOT** alter core semantics; clients **MUST** safely ignore unknown extensions.
- Version negotiation:
  - Clients MAY send `Accept-Schema-Version: X.Y` (or via query param).
  - Server responds with `Schema-Version: X.Y` and MUST NOT return newer-than-requested breaking shapes.

---

## Annex E — Error Taxonomy (Normative)

Representative (not exhaustive):

- `VALIDATION_FAILED`, `UNKNOWN_FIELD`, `TYPE_MISMATCH`, `FORMAT_INVALID`, `ENUM_INVALID`
- `IDEMPOTENT_REPLAY`, `SEQUENCE_REWIND`, `CLOCK_SKEW`
- `TAG_ALREADY_BOUND`, `TAG_NOT_BOUND`, `CTB_CYCLE`, `DEPTH_LIMIT`
- `TX_OPEN_EXISTS`, `TX_NOT_FOUND`, `POLICY_BLOCKED`, `FORBIDDEN`, `UNAUTHENTICATED`

Errors return `{ code, message, path?, details? }`; `path` is a JSON Pointer to the offending field or array element.

---

## Annex F — Payload Limits & Performance (Normative)

- **Event batch:** ≤ **5 000** events OR ≤ **5 MB** body size.
- **Search request:** page size ≤ **200**.
- **Response bodies:** SHOULD remain ≤ **2 MB**; larger payloads MUST paginate or stream.

---

## Annex G — Verification Artifacts (Normative)

- **Schema meta-validation**: all schemas pass draft-2020-12 meta-schema.
- **Example conformance**: embedded examples validate.
- **Generated types**: compile cleanly in consumer build.
- **Contract tests**: request examples validated in CI (strict mode).
- **Diff report**: MAJOR/MINOR/PATCH classifier output attached to PR.

---

### Why v1.4 is (realistically) done

- Covers **every** recurrent failure mode we see in mission-critical interfaces: strict ingress, event idempotency/order, units, time, field classification/retention, extension boundaries, size limits, and CI enforcement.
- Adds **reuse rules** (`$defs/$ref`) and **version negotiation**, which were the last material holes.
- Keeps the policy **compact** and implementable; anything further would be stylistic, not risk-reducing.

If you adopt this as-is, you’ll have a NASA-grade, auditable contract that your API, kiosks, and reviewers can rely on.

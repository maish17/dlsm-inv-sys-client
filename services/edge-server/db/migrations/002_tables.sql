-- services/edge-server/db/migrations/002_tables.sql
SET
    search_path = aether,
    public;

CREATE SCHEMA IF NOT EXISTS aether;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

SET
    search_path = aether,
    public;

-- 0) Physical locations (each rack/shelf/depth is unique)
CREATE TABLE
    IF NOT EXISTS aether.storage_sites (
        site_id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
        rack text NOT NULL,
        shelf smallint NOT NULL CHECK (shelf BETWEEN 1 AND 99),
        depth smallint NOT NULL CHECK (depth BETWEEN 1 AND 99),
        created_at timestamptz NOT NULL DEFAULT now (),
        updated_at timestamptz NOT NULL DEFAULT now (),
        UNIQUE (rack, shelf, depth)
    );

-- NEW: Users (crew). Keep it simple + idempotent friendly.
CREATE TABLE
    IF NOT EXISTS aether.users (
        user_id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
        full_name text NOT NULL,
        email text UNIQUE, -- optional; unique if present
        callsign text, -- optional, e.g. "Orion-1"
        active boolean NOT NULL DEFAULT true,
        created_at timestamptz NOT NULL DEFAULT now (),
        updated_at timestamptz NOT NULL DEFAULT now ()
    );

-- 1) Items (everything is an item; CTBs & Clothes are subtypes)
--    Ownership is optional: NULL user_id = communal.
CREATE TABLE
    IF NOT EXISTS aether.items (
        item_id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
        rfid text UNIQUE,
        name text NOT NULL,
        description text,
        size_m3 numeric(10, 4),
        mass_kg numeric(10, 3),
        status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'RETIRED')),
        site_id uuid NOT NULL REFERENCES aether.storage_sites (site_id) ON DELETE RESTRICT,
        user_id uuid REFERENCES aether.users (user_id) ON DELETE SET NULL, -- << optional owner
        created_at timestamptz NOT NULL DEFAULT now (),
        updated_at timestamptz NOT NULL DEFAULT now ()
    );

-- 2) CTBs: container-specific data (a CTB *is an item*; PK = FK to items)
CREATE TABLE
    IF NOT EXISTS aether.blobs (
        blob_id uuid PRIMARY KEY REFERENCES aether.items (item_id) ON DELETE CASCADE,
        slot_count smallint NOT NULL CHECK (slot_count BETWEEN 1 AND 4),
        created_at timestamptz NOT NULL DEFAULT now (),
        updated_at timestamptz NOT NULL DEFAULT now ()
    );

-- 3) Clothes: another subtype of items (1:1)
CREATE TABLE
    IF NOT EXISTS aether.clothes (
        item_id uuid PRIMARY KEY REFERENCES aether.items (item_id) ON DELETE CASCADE,
        size_label text,
        color text,
        material text,
        created_at timestamptz NOT NULL DEFAULT now (),
        updated_at timestamptz NOT NULL DEFAULT now ()
    );

-- 4) CTB contents: place items inside a CTB (supports nested CTBs)
--    child_item_id is UNIQUE so an item can only be in one CTB at a time.
CREATE TABLE
    IF NOT EXISTS aether.ctb_contents (
        parent_blob_id uuid NOT NULL REFERENCES aether.blobs (blob_id) ON DELETE CASCADE,
        child_item_id uuid NOT NULL UNIQUE REFERENCES aether.items (item_id) ON DELETE CASCADE,
        placed_at timestamptz NOT NULL DEFAULT now (),
        PRIMARY KEY (parent_blob_id, child_item_id)
    );

-- 5) Meal types: templates (0..255) + nutrition
CREATE TABLE
    IF NOT EXISTS aether.meal_types (
        code smallint PRIMARY KEY CHECK (code BETWEEN 0 AND 255),
        kind text NOT NULL CHECK (kind IN ('BASE', 'SPECIAL')),
        label text NOT NULL,
        energy_kcal integer CHECK (energy_kcal >= 0),
        vit_a_mcg_rae integer CHECK (vit_a_mcg_rae >= 0),
        vit_b2_mg numeric(8, 3) CHECK (vit_b2_mg >= 0),
        vit_b3_mg numeric(8, 3) CHECK (vit_b3_mg >= 0),
        vit_b4_mg numeric(8, 3) CHECK (vit_b4_mg >= 0),
        vit_b5_mg numeric(8, 3) CHECK (vit_b5_mg >= 0),
        vit_b6_mg numeric(8, 3) CHECK (vit_b6_mg >= 0),
        vit_b7_mg numeric(8, 3) CHECK (vit_b7_mg >= 0),
        vit_b8_mg numeric(8, 3) CHECK (vit_b8_mg >= 0),
        vit_b9_mg numeric(8, 3) CHECK (vit_b9_mg >= 0),
        vit_b10_mg numeric(8, 3) CHECK (vit_b10_mg >= 0),
        vit_b11_mg numeric(8, 3) CHECK (vit_b11_mg >= 0),
        vit_b12_mg numeric(8, 3) CHECK (vit_b12_mg >= 0),
        created_at timestamptz NOT NULL DEFAULT now (),
        updated_at timestamptz NOT NULL DEFAULT now ()
    );

-- 6) Meals: units in CTB slots (1..4); meals are *not* items
CREATE TABLE
    IF NOT EXISTS aether.meals (
        meal_id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
        blob_id uuid NOT NULL REFERENCES aether.blobs (blob_id) ON DELETE RESTRICT,
        slot smallint NOT NULL CHECK (slot BETWEEN 1 AND 4),
        meal_type_code smallint NOT NULL REFERENCES aether.meal_types (code) ON DELETE RESTRICT,
        is_special boolean NOT NULL DEFAULT false,
        expiration_date date NOT NULL,
        status text NOT NULL DEFAULT 'FRESH' CHECK (status IN ('FRESH', 'EXPIRED', 'DISPOSED')),
        created_at timestamptz NOT NULL DEFAULT now (),
        updated_at timestamptz NOT NULL DEFAULT now (),
        UNIQUE (blob_id, slot)
    );

-- 7) Scientific equipment (1:1 with items)
CREATE TABLE
    IF NOT EXISTS aether.scientific_equipment (
        item_id uuid PRIMARY KEY REFERENCES aether.items (item_id) ON DELETE CASCADE,
        manufacturer text,
        model text,
        serial_no text, -- often unique per unit
        calibration_due date, -- next calibration due date
        power_watts numeric(10, 2), -- nominal power draw
        hazardous boolean NOT NULL DEFAULT false, -- e.g., laser, chemicals, HV
        notes text,
        created_at timestamptz NOT NULL DEFAULT now (),
        updated_at timestamptz NOT NULL DEFAULT now ()
    );

-- 8) Spare parts (1:1 with items)
CREATE TABLE
    IF NOT EXISTS aether.spare_parts (
        item_id uuid PRIMARY KEY REFERENCES aether.items (item_id) ON DELETE CASCADE,
        part_no text, -- manufacturer P/N
        compatible_with text, -- free-form: model list / system
        lot_code text,
        lifetime_cycles integer CHECK (
            lifetime_cycles IS NULL
            OR lifetime_cycles >= 0
        ),
        expiration_date date,
        created_at timestamptz NOT NULL DEFAULT now (),
        updated_at timestamptz NOT NULL DEFAULT now ()
    );

-- 9) Medical supplies (1:1 with items)
CREATE TABLE
    IF NOT EXISTS aether.medical_supplies (
        item_id uuid PRIMARY KEY REFERENCES aether.items (item_id) ON DELETE CASCADE,
        category text, -- 'drug','device','consumable', etc. (free-form for now)
        lot_code text,
        expiry_date date,
        sterile boolean NOT NULL DEFAULT false,
        controlled boolean NOT NULL DEFAULT false, -- needs special custody?
        created_at timestamptz NOT NULL DEFAULT now (),
        updated_at timestamptz NOT NULL DEFAULT now ()
    );

-- 10) Hygiene items (1:1 with items)
CREATE TABLE
    IF NOT EXISTS aether.hygiene_items (
        item_id uuid PRIMARY KEY REFERENCES aether.items (item_id) ON DELETE CASCADE,
        category text, -- 'toothpaste','wipes','soap', etc.
        expiry_date date,
        units integer CHECK (
            units IS NULL
            OR units >= 0
        ),
        disposable boolean NOT NULL DEFAULT true,
        created_at timestamptz NOT NULL DEFAULT now (),
        updated_at timestamptz NOT NULL DEFAULT now ()
    );

-- 11) Waste containers (1:1 with items)
CREATE TABLE
    IF NOT EXISTS aether.waste_containers (
        item_id uuid PRIMARY KEY REFERENCES aether.items (item_id) ON DELETE CASCADE,
        waste_type text, -- 'DRY','WET','BIO','HAZ', etc. (free-form for now)
        sealed boolean NOT NULL DEFAULT false,
        generated_at timestamptz, -- when the waste started being collected
        volume_l numeric(10, 3) CHECK (
            volume_l IS NULL
            OR volume_l >= 0
        ),
        created_at timestamptz NOT NULL DEFAULT now (),
        updated_at timestamptz NOT NULL DEFAULT now ()
    );
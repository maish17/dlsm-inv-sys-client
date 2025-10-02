-- db/align_tables.sql
SET search_path = aether, public;

-- Ensure schema + uuid generator
CREATE SCHEMA IF NOT EXISTS aether;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 0) storage_sites
CREATE TABLE IF NOT EXISTS aether.storage_sites (
  site_id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rack      text NOT NULL,
  shelf     smallint NOT NULL CHECK (shelf BETWEEN 1 AND 99),
  depth     smallint NOT NULL CHECK (depth BETWEEN 1 AND 99),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (rack, shelf, depth)
);

-- 1) items (add table or patch columns)
CREATE TABLE IF NOT EXISTS aether.items (
  item_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rfid       text UNIQUE,
  name       text NOT NULL,
  description text,
  size_m3    numeric(10,4),
  mass_kg    numeric(10,3),
  status     text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','RETIRED')),
  site_id    uuid NOT NULL REFERENCES aether.storage_sites(site_id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- In case items existed already without some columns:
ALTER TABLE aether.items ADD COLUMN IF NOT EXISTS rfid        text;
ALTER TABLE aether.items ADD COLUMN IF NOT EXISTS name        text;
ALTER TABLE aether.items ALTER COLUMN name DROP NOT NULL;  -- temp while we backfill
ALTER TABLE aether.items ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE aether.items ADD COLUMN IF NOT EXISTS size_m3     numeric(10,4);
ALTER TABLE aether.items ADD COLUMN IF NOT EXISTS mass_kg     numeric(10,3);
ALTER TABLE aether.items ADD COLUMN IF NOT EXISTS status      text;
ALTER TABLE aether.items ADD COLUMN IF NOT EXISTS site_id     uuid;
ALTER TABLE aether.items ADD COLUMN IF NOT EXISTS created_at  timestamptz DEFAULT now();
ALTER TABLE aether.items ADD COLUMN IF NOT EXISTS updated_at  timestamptz DEFAULT now();

-- Defaults & checks if old rows exist
UPDATE aether.items SET status='ACTIVE' WHERE status IS NULL;
-- Backfill a site if some rows have NULL site_id (puts them in a default slot)
INSERT INTO aether.storage_sites(rack,shelf,depth)
VALUES ('RACK-DEFAULT',1,1)
ON CONFLICT (rack,shelf,depth) DO NOTHING;

UPDATE aether.items
SET site_id = COALESCE(site_id, (
  SELECT site_id FROM aether.storage_sites
  WHERE rack='RACK-DEFAULT' AND shelf=1 AND depth=1
  LIMIT 1
));

-- Now enforce NOT NULL / constraints
ALTER TABLE aether.items ALTER COLUMN name   SET NOT NULL;
ALTER TABLE aether.items ALTER COLUMN site_id SET NOT NULL;
ALTER TABLE aether.items
  ADD CONSTRAINT items_status_chk CHECK (status IN ('ACTIVE','RETIRED')) NOT VALID;
-- cheap uniqueness if table was old without a UNIQUE
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname='aether' AND indexname='idx_items_rfid_unique'
  ) THEN
    CREATE UNIQUE INDEX idx_items_rfid_unique ON aether.items(rfid);
  END IF;
END$$;

-- 2) blobs (CTBs)
CREATE TABLE IF NOT EXISTS aether.blobs (
  blob_id     uuid PRIMARY KEY REFERENCES aether.items(item_id) ON DELETE CASCADE,
  slot_count  smallint NOT NULL CHECK (slot_count BETWEEN 1 AND 4),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- 3) clothes
CREATE TABLE IF NOT EXISTS aether.clothes (
  item_id     uuid PRIMARY KEY REFERENCES aether.items(item_id) ON DELETE CASCADE,
  size_label  text,
  color       text,
  material    text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- 4) ctb_contents (nesting)
CREATE TABLE IF NOT EXISTS aether.ctb_contents (
  parent_blob_id uuid NOT NULL REFERENCES aether.blobs(blob_id) ON DELETE CASCADE,
  child_item_id  uuid NOT NULL UNIQUE REFERENCES aether.items(item_id) ON DELETE CASCADE,
  placed_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (parent_blob_id, child_item_id)
);

-- 5) meal_types
CREATE TABLE IF NOT EXISTS aether.meal_types (
  code smallint PRIMARY KEY CHECK (code BETWEEN 0 AND 255),
  kind text NOT NULL CHECK (kind IN ('BASE','SPECIAL')),
  label text NOT NULL,
  energy_kcal integer CHECK (energy_kcal >= 0),
  vit_a_mcg_rae integer CHECK (vit_a_mcg_rae >= 0),
  vit_b2_mg  numeric(8,3) CHECK (vit_b2_mg  >= 0),
  vit_b3_mg  numeric(8,3) CHECK (vit_b3_mg  >= 0),
  vit_b4_mg  numeric(8,3) CHECK (vit_b4_mg  >= 0),
  vit_b5_mg  numeric(8,3) CHECK (vit_b5_mg  >= 0),
  vit_b6_mg  numeric(8,3) CHECK (vit_b6_mg  >= 0),
  vit_b7_mg  numeric(8,3) CHECK (vit_b7_mg  >= 0),
  vit_b8_mg  numeric(8,3) CHECK (vit_b8_mg  >= 0),
  vit_b9_mg  numeric(8,3) CHECK (vit_b9_mg  >= 0),
  vit_b10_mg numeric(8,3) CHECK (vit_b10_mg >= 0),
  vit_b11_mg numeric(8,3) CHECK (vit_b11_mg >= 0),
  vit_b12_mg numeric(8,3) CHECK (vit_b12_mg >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 6) meals
CREATE TABLE IF NOT EXISTS aether.meals (
  meal_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  blob_id        uuid NOT NULL REFERENCES aether.blobs(blob_id) ON DELETE RESTRICT,
  slot           smallint NOT NULL CHECK (slot BETWEEN 1 AND 4),
  meal_type_code smallint NOT NULL REFERENCES aether.meal_types(code) ON DELETE RESTRICT,
  is_special     boolean NOT NULL DEFAULT false,
  expiration_date date NOT NULL,
  status         text NOT NULL DEFAULT 'FRESH' CHECK (status IN ('FRESH','EXPIRED','DISPOSED')),
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (blob_id, slot)
);
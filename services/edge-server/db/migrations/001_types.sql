-- services/edge-server/db/migrations/001_types.sql
SET search_path = aether, public;

CREATE SCHEMA IF NOT EXISTS aether;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Touch helper for updated_at (future-proof; not used by triggers yet)
CREATE OR REPLACE FUNCTION aether.touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END$$;

-- ---- Core enums ----

-- Item lifecycle/status: base truth for aether.items.status
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname='aether' AND t.typname='item_status'
  ) THEN
    CREATE TYPE aether.item_status AS ENUM ('ACTIVE','RETIRED','LOST');
  END IF;
END$$;

-- Meals catalog & instances
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE n.nspname='aether' AND t.typname='meal_kind'
  ) THEN
    CREATE TYPE aether.meal_kind AS ENUM ('BASE','SPECIAL');
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE n.nspname='aether' AND t.typname='meal_status'
  ) THEN
    CREATE TYPE aether.meal_status AS ENUM ('FRESH','EXPIRED','DISPOSED');
  END IF;
END$$;

-- ---- Domain enums for inventory subtypes ----
-- Principle: constrain common cases, but always keep an 'OTHER' bucket
-- so we don’t block real-world edge cases. (WWND)

-- Clothing sizes (optional; you can skip applying if you need free form)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE n.nspname='aether' AND t.typname='clothing_size'
  ) THEN
    CREATE TYPE aether.clothing_size AS ENUM ('XS','S','M','L','XL','XXL','CUSTOM');
  END IF;
END$$;

-- Medical categorization
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE n.nspname='aether' AND t.typname='medical_category'
  ) THEN
    CREATE TYPE aether.medical_category AS ENUM ('DRUG','DEVICE','CONSUMABLE','PPE','OTHER');
  END IF;
END$$;

-- Hygiene categorization
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE n.nspname='aether' AND t.typname='hygiene_category'
  ) THEN
    CREATE TYPE aether.hygiene_category AS ENUM ('TOOTHPASTE','WIPES','SOAP','SHAMPOO','DEODORANT','OTHER');
  END IF;
END$$;

-- Waste container contents
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE n.nspname='aether' AND t.typname='waste_type'
  ) THEN
    CREATE TYPE aether.waste_type AS ENUM ('DRY','WET','BIO','HAZ','SHARPS','OTHER');
  END IF;
END$$;

-- (Legacy / future: defined but not currently used)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE n.nspname='aether' AND t.typname='blob_status'
  ) THEN
    CREATE TYPE aether.blob_status AS ENUM ('ACTIVE','RETIRED');
  END IF;
END$$;
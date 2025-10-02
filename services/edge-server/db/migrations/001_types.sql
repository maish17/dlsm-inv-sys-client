-- 001_types.sql
SET search_path = aether, public;

CREATE SCHEMA IF NOT EXISTS aether;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- item_status (NEW — required by aether.items)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'aether' AND t.typname = 'item_status'
  ) THEN
    CREATE TYPE aether.item_status AS ENUM ('ACTIVE','RETIRED','LOST');
  END IF;
END$$;

-- (you can keep these if you still reference them anywhere)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'aether' AND t.typname = 'blob_status'
  ) THEN
    CREATE TYPE aether.blob_status AS ENUM ('ACTIVE','RETIRED');
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'aether' AND t.typname = 'meal_status'
  ) THEN
    CREATE TYPE aether.meal_status AS ENUM ('FRESH','EXPIRED','DISPOSED');
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'aether' AND t.typname = 'meal_kind'
  ) THEN
    CREATE TYPE aether.meal_kind AS ENUM ('BASE','SPECIAL');
  END IF;
END$$;

-- touch() helper for updated_at
CREATE OR REPLACE FUNCTION aether.touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END$$;
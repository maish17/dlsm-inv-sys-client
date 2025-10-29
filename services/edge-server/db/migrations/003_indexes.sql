SET search_path = aether, public;

-- =========================
-- Core container relations
-- =========================

-- Reverse lookup: "what CTB holds this item?"
CREATE INDEX IF NOT EXISTS idx_ctb_child
  ON aether.ctb_contents (child_item_id);

-- Note: PK (parent_blob_id, child_item_id) already indexes parent_blob_id.

-- =========================
-- Items: hot paths
-- =========================

-- Fast "all ACTIVE items for a user"
CREATE INDEX IF NOT EXISTS idx_items_active_by_user
  ON aether.items (user_id)
  WHERE status = 'ACTIVE'::aether.item_status;

-- Fast "all ACTIVE items at a site"
CREATE INDEX IF NOT EXISTS idx_items_active_by_site
  ON aether.items (site_id)
  WHERE status = 'ACTIVE'::aether.item_status;

-- Optional: keep if you often paginate by created time
CREATE INDEX IF NOT EXISTS idx_blobs_created_at
  ON aether.blobs (created_at);

-- =========================
-- Meals & meal types
-- =========================

-- Unique (blob_id, slot) from the table definition already exists and
-- covers queries on blob_id and (blob_id, slot). We do NOT add separate
-- indexes on blob or slot.

CREATE INDEX IF NOT EXISTS idx_meals_type
  ON aether.meals (meal_type_code);

CREATE INDEX IF NOT EXISTS idx_meals_exp
  ON aether.meals (expiration_date);

CREATE INDEX IF NOT EXISTS idx_meals_status
  ON aether.meals (status);

-- Browse by BASE vs SPECIAL
CREATE INDEX IF NOT EXISTS idx_meal_types_kind
  ON aether.meal_types (kind);

-- =========================
-- Users (lightweight)
-- =========================

CREATE INDEX IF NOT EXISTS idx_users_active
  ON aether.users (active);

-- Helps ORDER BY / prefix searches on full_name; for fuzzy search we’ll
-- add trigram later.
CREATE INDEX IF NOT EXISTS idx_users_full_name
  ON aether.users (full_name);

-- =========================
-- Subtypes
-- =========================

-- Serial numbers are typically unique per unit; make it unique when present.
CREATE UNIQUE INDEX IF NOT EXISTS idx_sci_equipment_serial_unq
  ON aether.scientific_equipment (serial_no)
  WHERE serial_no IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sci_equipment_calib
  ON aether.scientific_equipment (calibration_due);

CREATE INDEX IF NOT EXISTS idx_spare_parts_part_no
  ON aether.spare_parts (part_no);

CREATE INDEX IF NOT EXISTS idx_spare_parts_expiry
  ON aether.spare_parts (expiration_date);

CREATE INDEX IF NOT EXISTS idx_medical_expiry
  ON aether.medical_supplies (expiry_date);

CREATE INDEX IF NOT EXISTS idx_medical_category
  ON aether.medical_supplies (category);

CREATE INDEX IF NOT EXISTS idx_hygiene_expiry
  ON aether.hygiene_items (expiry_date);

CREATE INDEX IF NOT EXISTS idx_hygiene_category
  ON aether.hygiene_items (category);

CREATE INDEX IF NOT EXISTS idx_waste_type
  ON aether.waste_containers (waste_type);

CREATE INDEX IF NOT EXISTS idx_waste_generated_at
  ON aether.waste_containers (generated_at);
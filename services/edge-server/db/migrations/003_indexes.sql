-- services/edge-server/db/migrations/003_indexes.sql
SET
    search_path = aether,
    public;

-- Existing…
CREATE INDEX IF NOT EXISTS idx_blobs_created_at ON aether.blobs (created_at);

CREATE INDEX IF NOT EXISTS idx_meal_types_code ON aether.meal_types (code);

CREATE INDEX IF NOT EXISTS idx_meals_blob ON aether.meals (blob_id);

CREATE INDEX IF NOT EXISTS idx_meals_slot ON aether.meals (slot);

CREATE INDEX IF NOT EXISTS idx_meals_type ON aether.meals (meal_type_code);

CREATE INDEX IF NOT EXISTS idx_meals_exp ON aether.meals (expiration_date);

CREATE INDEX IF NOT EXISTS idx_meals_status ON aether.meals (status);

CREATE INDEX IF NOT EXISTS idx_meals_special ON aether.meals (is_special);

-- New: users + item ownership
CREATE INDEX IF NOT EXISTS idx_users_active ON aether.users (active);

CREATE INDEX IF NOT EXISTS idx_users_full_name ON aether.users (full_name);

CREATE INDEX IF NOT EXISTS idx_items_user_id ON aether.items (user_id);

CREATE INDEX IF NOT EXISTS idx_items_site_id ON aether.items (site_id);

CREATE INDEX IF NOT EXISTS idx_items_status ON aether.items (status);

-- Subtype indexes
CREATE INDEX IF NOT EXISTS idx_sci_equipment_serial ON aether.scientific_equipment (serial_no);

CREATE INDEX IF NOT EXISTS idx_sci_equipment_calib ON aether.scientific_equipment (calibration_due);

CREATE INDEX IF NOT EXISTS idx_spare_parts_part_no ON aether.spare_parts (part_no);

CREATE INDEX IF NOT EXISTS idx_spare_parts_expiry ON aether.spare_parts (expiration_date);

CREATE INDEX IF NOT EXISTS idx_medical_expiry ON aether.medical_supplies (expiry_date);

CREATE INDEX IF NOT EXISTS idx_medical_category ON aether.medical_supplies (category);

CREATE INDEX IF NOT EXISTS idx_hygiene_expiry ON aether.hygiene_items (expiry_date);

CREATE INDEX IF NOT EXISTS idx_hygiene_category ON aether.hygiene_items (category);

CREATE INDEX IF NOT EXISTS idx_waste_type ON aether.waste_containers (waste_type);

CREATE INDEX IF NOT EXISTS idx_waste_generated_at ON aether.waste_containers (generated_at);
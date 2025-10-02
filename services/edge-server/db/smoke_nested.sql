-- Minimal smoke: meal type, meal in a blob (CTB), clothing in inner CTB which is in outer CTB.
SET
    search_path = aether,
    public;

-- 0) Physical location (needed because items.site_id is NOT NULL)
INSERT INTO
    storage_sites (rack, shelf, depth)
VALUES
    ('Rack-A', 1, 1) ON CONFLICT (rack, shelf, depth) DO NOTHING;

-- 1) OUTER CTB (item + blob)
INSERT INTO
    items (rfid, name, site_id, status)
SELECT
    'RFID-CTB-OUTER',
    'CTB-Outer',
    s.site_id,
    'ACTIVE'
FROM
    storage_sites s
WHERE
    s.rack = 'Rack-A'
    AND s.shelf = 1
    AND s.depth = 1 ON CONFLICT (rfid) DO NOTHING;

INSERT INTO
    blobs (blob_id, slot_count)
SELECT
    i.item_id,
    4
FROM
    items i
WHERE
    i.rfid = 'RFID-CTB-OUTER' ON CONFLICT (blob_id) DO NOTHING;

-- 2) INNER CTB (item + blob), lives inside OUTER CTB
INSERT INTO
    items (rfid, name, site_id, status)
SELECT
    'RFID-CTB-INNER',
    'CTB-Inner',
    s.site_id,
    'ACTIVE'
FROM
    storage_sites s
WHERE
    s.rack = 'Rack-A'
    AND s.shelf = 1
    AND s.depth = 1 ON CONFLICT (rfid) DO NOTHING;

INSERT INTO
    blobs (blob_id, slot_count)
SELECT
    i.item_id,
    4
FROM
    items i
WHERE
    i.rfid = 'RFID-CTB-INNER' ON CONFLICT (blob_id) DO NOTHING;

-- Link inner CTB under outer CTB
INSERT INTO
    ctb_contents (parent_blob_id, child_item_id)
SELECT
    b_outer.blob_id,
    i_inner.item_id
FROM
    items i_outer
    JOIN blobs b_outer ON b_outer.blob_id = i_outer.item_id
    JOIN items i_inner ON i_inner.rfid = 'RFID-CTB-INNER'
WHERE
    i_outer.rfid = 'RFID-CTB-OUTER' ON CONFLICT DO NOTHING;

-- 3) Meal type + Meal in INNER CTB slot 1
INSERT INTO
    meal_types (code, kind, label, energy_kcal, vit_a_mcg_rae)
VALUES
    (10, 'BASE', 'High-Protein Dinner', 700, 900) ON CONFLICT (code) DO
UPDATE
SET
    label = EXCLUDED.label,
    energy_kcal = EXCLUDED.energy_kcal,
    vit_a_mcg_rae = EXCLUDED.vit_a_mcg_rae;

INSERT INTO
    meals (
        blob_id,
        slot,
        meal_type_code,
        is_special,
        expiration_date
    )
SELECT
    b_inner.blob_id,
    1,
    10,
    FALSE,
    DATE '2026-04-10'
FROM
    items i_inner
    JOIN blobs b_inner ON b_inner.blob_id = i_inner.item_id
WHERE
    i_inner.rfid = 'RFID-CTB-INNER' ON CONFLICT (blob_id, slot) DO NOTHING;

-- 4) Clothing item + subtype row, placed in INNER CTB
INSERT INTO
    items (rfid, name, description, site_id, status)
SELECT
    'RFID-CLOTH-1',
    'Thermal Shirt',
    'Crew thermal layer',
    s.site_id,
    'ACTIVE'
FROM
    storage_sites s
WHERE
    s.rack = 'Rack-A'
    AND s.shelf = 1
    AND s.depth = 1 ON CONFLICT (rfid) DO NOTHING;

INSERT INTO
    clothes (item_id, size_label, color, material)
SELECT
    i.item_id,
    'M',
    'Navy',
    'Polymer-fiber'
FROM
    items i
WHERE
    i.rfid = 'RFID-CLOTH-1' ON CONFLICT (item_id) DO NOTHING;

INSERT INTO
    ctb_contents (parent_blob_id, child_item_id)
SELECT
    b_inner.blob_id,
    i_cloth.item_id
FROM
    items i_inner
    JOIN blobs b_inner ON b_inner.blob_id = i_inner.item_id
    JOIN items i_cloth ON i_cloth.rfid = 'RFID-CLOTH-1'
WHERE
    i_inner.rfid = 'RFID-CTB-INNER' ON CONFLICT DO NOTHING;

-- (Optional) Quick sanity: show the IDs we made
SELECT
    (
        SELECT
            blob_id
        FROM
            blobs b
            JOIN items i ON i.item_id = b.blob_id
        WHERE
            i.rfid = 'RFID-CTB-OUTER'
    ) AS outer_ctb,
    (
        SELECT
            blob_id
        FROM
            blobs b
            JOIN items i ON i.item_id = b.blob_id
        WHERE
            i.rfid = 'RFID-CTB-INNER'
    ) AS inner_ctb,
    (
        SELECT
            meal_id
        FROM
            meals m
            JOIN blobs b ON b.blob_id = m.blob_id
            JOIN items i ON i.item_id = b.blob_id
        WHERE
            i.rfid = 'RFID-CTB-INNER'
            AND m.slot = 1
    ) AS meal_id,
    (
        SELECT
            item_id
        FROM
            items
        WHERE
            rfid = 'RFID-CLOTH-1'
    ) AS clothing_item_id;
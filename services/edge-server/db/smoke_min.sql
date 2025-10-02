-- db/smoke_min.sql
SET
    search_path = aether,
    public;

-- Location
INSERT INTO
    storage_sites (rack, shelf, depth)
VALUES
    ('Rack-A', 1, 1) ON CONFLICT (rack, shelf, depth) DO NOTHING;

-- OUTER CTB
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

-- INNER CTB inside OUTER CTB
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

-- Meal type + Meal in inner CTB slot 1
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
    b.blob_id,
    1,
    10,
    FALSE,
    DATE '2026-04-10'
FROM
    items i
    JOIN blobs b ON b.blob_id = i.item_id
WHERE
    i.rfid = 'RFID-CTB-INNER' ON CONFLICT (blob_id, slot) DO NOTHING;

-- Clothing item in inner CTB
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
    b.blob_id,
    i.item_id
FROM
    items i
    JOIN items i_ctb ON i_ctb.rfid = 'RFID-CTB-INNER'
    JOIN blobs b ON b.blob_id = i_ctb.item_id
WHERE
    i.rfid = 'RFID-CLOTH-1' ON CONFLICT DO NOTHING;

-- Show IDs
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

-- Effective locations (walk up CTB parents to top-most; use top's site)
WITH RECURSIVE
    chain_meal AS (
        SELECT
            i.item_id,
            i.site_id,
            0 AS level
        FROM
            items i
        WHERE
            i.item_id = (
                SELECT
                    b.blob_id
                FROM
                    meals m
                    JOIN blobs b ON b.blob_id = m.blob_id
                    JOIN items ii ON ii.item_id = b.blob_id
                WHERE
                    ii.rfid = 'RFID-CTB-INNER'
                    AND m.slot = 1
            )
        UNION ALL
        SELECT
            p_i.item_id,
            p_i.site_id,
            c.level + 1
        FROM
            chain_meal c
            JOIN ctb_contents cc ON cc.child_item_id = c.item_id
            JOIN blobs pb ON pb.blob_id = cc.parent_blob_id
            JOIN items p_i ON p_i.item_id = pb.blob_id
    ),
    top_meal AS (
        SELECT
            site_id
        FROM
            chain_meal
        ORDER BY
            level DESC
        LIMIT
            1
    )
SELECT
    'MEAL_LOCATION' AS label,
    s.rack,
    s.shelf,
    s.depth
FROM
    top_meal tm
    JOIN storage_sites s ON s.site_id = tm.site_id;

WITH RECURSIVE
    chain_cloth AS (
        SELECT
            i.item_id,
            i.site_id,
            0 AS level
        FROM
            items i
        WHERE
            i.rfid = 'RFID-CLOTH-1'
        UNION ALL
        SELECT
            p_i.item_id,
            p_i.site_id,
            c.level + 1
        FROM
            chain_cloth c
            JOIN ctb_contents cc ON cc.child_item_id = c.item_id
            JOIN blobs pb ON pb.blob_id = cc.parent_blob_id
            JOIN items p_i ON p_i.item_id = pb.blob_id
    ),
    top_cloth AS (
        SELECT
            site_id
        FROM
            chain_cloth
        ORDER BY
            level DESC
        LIMIT
            1
    )
SELECT
    'CLOTHING_LOCATION' AS label,
    s.rack,
    s.shelf,
    s.depth
FROM
    top_cloth tc
    JOIN storage_sites s ON s.site_id = tc.site_id;
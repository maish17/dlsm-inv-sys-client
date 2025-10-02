-- services/edge-server/db/smoke_users.sql
SET
    search_path = aether,
    public;

-- 0) Site
INSERT INTO
    aether.storage_sites (rack, shelf, depth)
VALUES
    ('RACK-A', 1, 1) ON CONFLICT (rack, shelf, depth) DO NOTHING;

-- 1) Two users
INSERT INTO
    aether.users (full_name, email)
VALUES
    ('Person A', 'a@example.local'),
    ('Person B', 'b@example.local') ON CONFLICT (email) DO NOTHING;

-- Grab IDs
WITH
    u AS (
        SELECT
            user_id
        FROM
            aether.users
        WHERE
            email = 'a@example.local'
        LIMIT
            1
    ),
    s AS (
        SELECT
            site_id
        FROM
            aether.storage_sites
        WHERE
            rack = 'RACK-A'
            AND shelf = 1
            AND depth = 1
    )
    -- 2) Make an owned CTB (outer)
,
    outer_item AS (
        INSERT INTO
            aether.items (rfid, name, site_id, status, user_id)
        SELECT
            'RFID-CTB-OUTER',
            'CTB-Outer',
            s.site_id,
            'ACTIVE',
            u.user_id
        FROM
            s,
            u RETURNING item_id
    ),
    outer_blob AS (
        INSERT INTO
            aether.blobs (blob_id, slot_count)
        SELECT
            item_id,
            4
        FROM
            outer_item RETURNING blob_id
    )
    -- 3) Make an inner CTB (communal) and nest inside outer
,
    inner_item AS (
        INSERT INTO
            aether.items (rfid, name, site_id, status, user_id)
        SELECT
            'RFID-CTB-INNER',
            'CTB-Inner',
            s.site_id,
            'ACTIVE',
            NULL
        FROM
            s RETURNING item_id
    ),
    inner_blob AS (
        INSERT INTO
            aether.blobs (blob_id, slot_count)
        SELECT
            item_id,
            4
        FROM
            inner_item RETURNING blob_id
    ),
    nest AS (
        INSERT INTO
            aether.ctb_contents (parent_blob_id, child_item_id)
        SELECT
            (
                SELECT
                    blob_id
                FROM
                    outer_blob
            ),
            (
                SELECT
                    item_id
                FROM
                    inner_item
            ) RETURNING parent_blob_id,
            child_item_id
    )
    -- 4) Put an item inside inner CTB, owned by Person B
,
    cloth_item AS (
        INSERT INTO
            aether.items (rfid, name, description, site_id, status, user_id)
        SELECT
            'RFID-CLOTH-1',
            'Thermal Shirt',
            'Crew thermal layer',
            s.site_id,
            'ACTIVE',
            (
                SELECT
                    user_id
                FROM
                    aether.users
                WHERE
                    email = 'b@example.local'
            )
        FROM
            s RETURNING item_id
    ),
    cloth_sub AS (
        INSERT INTO
            aether.clothes (item_id, size_label, color, material)
        SELECT
            item_id,
            'M',
            'Navy',
            'Polymer-fiber'
        FROM
            cloth_item RETURNING item_id
    ),
    link_cloth AS (
        INSERT INTO
            aether.ctb_contents (parent_blob_id, child_item_id)
        SELECT
            (
                SELECT
                    blob_id
                FROM
                    inner_blob
            ),
            (
                SELECT
                    item_id
                FROM
                    cloth_item
            ) RETURNING parent_blob_id,
            child_item_id
    )
    -- 5) Add a meal type + a meal into inner CTB slot 1 (communal)
,
    mt AS (
        INSERT INTO
            aether.meal_types (code, kind, label, energy_kcal, vit_a_mcg_rae)
        VALUES
            (10, 'BASE', 'High-Protein Dinner', 700, 900) ON CONFLICT (code) DO
        UPDATE
        SET
            label = EXCLUDED.label RETURNING code
    ),
    meal_row AS (
        INSERT INTO
            aether.meals (
                blob_id,
                slot,
                meal_type_code,
                is_special,
                expiration_date
            )
        SELECT
            (
                SELECT
                    blob_id
                FROM
                    inner_blob
            ),
            1,
            (
                SELECT
                    code
                FROM
                    mt
            ),
            FALSE,
            DATE '2026-04-10' RETURNING meal_id
    )
SELECT
    (
        SELECT
            blob_id
        FROM
            outer_blob
    ) AS outer_ctb,
    (
        SELECT
            blob_id
        FROM
            inner_blob
    ) AS inner_ctb,
    (
        SELECT
            item_id
        FROM
            cloth_item
    ) AS clothing_item,
    (
        SELECT
            meal_id
        FROM
            meal_row
    ) AS meal_id;

-- Show ownership
SELECT
    i.item_id,
    i.name,
    u.full_name AS owner
FROM
    aether.items i
    LEFT JOIN aether.users u ON u.user_id = i.user_id
WHERE
    i.name IN ('CTB-Outer', 'CTB-Inner', 'Thermal Shirt')
ORDER BY
    i.name;
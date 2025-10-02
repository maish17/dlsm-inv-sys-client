SET
    search_path = aether,
    public;

-- keep seeded types; just reset blobs/meals
TRUNCATE TABLE aether.meals,
aether.blobs RESTART IDENTITY CASCADE;

-- insert one blob and 4 meals mapped to types 1..4
WITH
    b AS (
        INSERT INTO
            aether.blobs (rfid, slot_count, status)
        VALUES
            ('RFID-ABC123', 4, 'ACTIVE') RETURNING blob_id
    )
INSERT INTO
    aether.meals (
        blob_id,
        slot,
        meal_type_code,
        is_special,
        expiration_date,
        status
    )
SELECT
    b.blob_id,
    s.slot,
    s.type_code,
    FALSE,
    DATE '2026-04-10',
    'FRESH'
FROM
    b
    JOIN (
        VALUES
            (1, 1),
            (2, 2),
            (3, 3),
            (4, 4)
    ) AS s (slot, type_code) ON TRUE;

-- sanity: view should exist and show 4 rows
TABLE aether.v_meals_with_type
ORDER BY
    slot;

-- mark expired meals (if any) to prove updates + trigger
UPDATE aether.meals
SET
    status = 'EXPIRED'
WHERE
    expiration_date < CURRENT_DATE;

-- explain a common RFID lookup
EXPLAIN ANALYZE
SELECT
    m.*
FROM
    aether.meals m
    JOIN aether.blobs b ON b.blob_id = m.blob_id
WHERE
    b.rfid = 'RFID-ABC123'
ORDER BY
    m.slot;
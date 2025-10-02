SET
    search_path = aether,
    public;

-- a site
INSERT INTO
    aether.storage_sites (rack, shelf, depth)
VALUES
    ('RACK-SMOKE', 1, 1) ON CONFLICT (rack, shelf, depth) DO NOTHING;

-- a communal CTB to hold things
WITH
    s AS (
        SELECT
            site_id
        FROM
            aether.storage_sites
        WHERE
            rack = 'RACK-SMOKE'
            AND shelf = 1
            AND depth = 1
    ),
    ctb_item AS (
        INSERT INTO
            aether.items (rfid, name, site_id, status)
        SELECT
            'RFID-CTB-SMOKE',
            'CTB-Smoke',
            s.site_id,
            'ACTIVE'
        FROM
            s RETURNING item_id
    )
INSERT INTO
    aether.blobs (blob_id, slot_count)
SELECT
    item_id,
    4
FROM
    ctb_item;

-- 1) scientific_equipment
WITH
    s AS (
        SELECT
            site_id
        FROM
            aether.storage_sites
        WHERE
            rack = 'RACK-SMOKE'
            AND shelf = 1
            AND depth = 1
    ),
    i AS (
        INSERT INTO
            aether.items (rfid, name, site_id, status)
        SELECT
            'RFID-SCI-1',
            'Spectrometer',
            s.site_id,
            'ACTIVE'
        FROM
            s RETURNING item_id
    )
INSERT INTO
    aether.scientific_equipment (
        item_id,
        manufacturer,
        model,
        serial_no,
        calibration_due,
        power_watts,
        hazardous,
        notes
    )
SELECT
    item_id,
    'ACME',
    'SP-200',
    'SN-001',
    DATE '2026-01-15',
    75.5,
    true,
    'Laser Class 3B'
FROM
    i;

-- 2) spare_parts
WITH
    s AS (
        SELECT
            site_id
        FROM
            aether.storage_sites
        WHERE
            rack = 'RACK-SMOKE'
            AND shelf = 1
            AND depth = 1
    ),
    i AS (
        INSERT INTO
            aether.items (rfid, name, site_id, status)
        SELECT
            'RFID-PART-1',
            'Pump Seal Kit',
            s.site_id,
            'ACTIVE'
        FROM
            s RETURNING item_id
    )
INSERT INTO
    aether.spare_parts (
        item_id,
        part_no,
        compatible_with,
        lot_code,
        lifetime_cycles,
        expiration_date
    )
SELECT
    item_id,
    'P-778A',
    'Fluid Pump v2',
    'LOT-A1',
    5000,
    DATE '2027-12-31'
FROM
    i;

-- 3) medical_supplies
WITH
    s AS (
        SELECT
            site_id
        FROM
            aether.storage_sites
        WHERE
            rack = 'RACK-SMOKE'
            AND shelf = 1
            AND depth = 1
    ),
    i AS (
        INSERT INTO
            aether.items (rfid, name, site_id, status)
        SELECT
            'RFID-MED-1',
            'Sterile Dressing Pack',
            s.site_id,
            'ACTIVE'
        FROM
            s RETURNING item_id
    )
INSERT INTO
    aether.medical_supplies (
        item_id,
        category,
        lot_code,
        expiry_date,
        sterile,
        controlled
    )
SELECT
    item_id,
    'consumable',
    'LOT-M1',
    DATE '2026-06-30',
    true,
    false
FROM
    i;

-- 4) hygiene_items
WITH
    s AS (
        SELECT
            site_id
        FROM
            aether.storage_sites
        WHERE
            rack = 'RACK-SMOKE'
            AND shelf = 1
            AND depth = 1
    ),
    i AS (
        INSERT INTO
            aether.items (rfid, name, site_id, status)
        SELECT
            'RFID-HYG-1',
            'Disinfectant Wipes',
            s.site_id,
            'ACTIVE'
        FROM
            s RETURNING item_id
    )
INSERT INTO
    aether.hygiene_items (item_id, category, expiry_date, units, disposable)
SELECT
    item_id,
    'wipes',
    DATE '2026-03-01',
    80,
    true
FROM
    i;

-- 5) waste_containers
WITH
    s AS (
        SELECT
            site_id
        FROM
            aether.storage_sites
        WHERE
            rack = 'RACK-SMOKE'
            AND shelf = 1
            AND depth = 1
    ),
    i AS (
        INSERT INTO
            aether.items (rfid, name, site_id, status)
        SELECT
            'RFID-WASTE-1',
            'Waste Bag - Bio',
            s.site_id,
            'ACTIVE'
        FROM
            s RETURNING item_id
    )
INSERT INTO
    aether.waste_containers (
        item_id,
        waste_type,
        sealed,
        generated_at,
        volume_l
    )
SELECT
    item_id,
    'BIO',
    false,
    now (),
    12.5
FROM
    i;

-- quick peek
SELECT
    'scientific_equipment' AS table,
    count(*)
FROM
    aether.scientific_equipment
UNION ALL
SELECT
    'spare_parts',
    count(*)
FROM
    aether.spare_parts
UNION ALL
SELECT
    'medical_supplies',
    count(*)
FROM
    aether.medical_supplies
UNION ALL
SELECT
    'hygiene_items',
    count(*)
FROM
    aether.hygiene_items
UNION ALL
SELECT
    'waste_containers',
    count(*)
FROM
    aether.waste_containers;
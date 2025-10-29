-- services/edge-server/db/migrations/004_views.sql
-- Reset & recreate all views (safe to re-run)
SET
    search_path = aether,
    public;

-- 0) Nuke prior views so CREATE works even if column lists changed
DROP VIEW IF EXISTS aether.v_meal_effective_location,
aether.v_item_effective_location,
aether.v_item_effective_site,
aether.v_items_catalog,
aether.v_item_kinds,
aether.v_ctb_slots,
aether.v_ctb_contents,
aether.v_items_with_owner_site,
aether.v_meals_with_type CASCADE;

-- 1) Meals + type
CREATE VIEW
    aether.v_meals_with_type AS
SELECT
    m.meal_id,
    m.blob_id,
    m.slot,
    m.is_special,
    m.expiration_date,
    m.status,
    t.code AS meal_type_code,
    t.kind AS meal_kind,
    t.label AS meal_label,
    t.energy_kcal
FROM
    aether.meals m
    JOIN aether.meal_types t ON t.code = m.meal_type_code;

-- 2) Items + owner + site
CREATE VIEW
    aether.v_items_with_owner_site AS
SELECT
    i.item_id,
    i.rfid,
    i.name,
    i.status,
    i.size_m3,
    i.mass_kg,
    u.user_id,
    u.full_name AS owner_name,
    s.site_id,
    s.rack,
    s.shelf,
    s.depth
FROM
    aether.items i
    LEFT JOIN aether.users u ON u.user_id = i.user_id
    JOIN aether.storage_sites s ON s.site_id = i.site_id;

-- 3) CTB immediate contents
CREATE VIEW
    aether.v_ctb_contents AS
SELECT
    c.parent_blob_id AS ctb_id,
    i.item_id,
    i.name AS item_name,
    i.status AS item_status,
    c.placed_at
FROM
    aether.ctb_contents c
    JOIN aether.items i ON i.item_id = c.child_item_id;

-- 4) CTB slots (all 1..slot_count) + any meal in each slot
CREATE VIEW
    aether.v_ctb_slots AS
SELECT
    b.blob_id AS ctb_id,
    gs.slot,
    m.meal_id,
    m.is_special,
    m.expiration_date,
    m.status AS meal_status,
    t.label AS meal_label,
    t.kind AS meal_kind,
    t.code AS meal_type_code
FROM
    aether.blobs b
    CROSS JOIN LATERAL generate_series (1, b.slot_count) AS gs (slot)
    LEFT JOIN aether.meals m ON m.blob_id = b.blob_id
    AND m.slot = gs.slot
    LEFT JOIN aether.meal_types t ON t.code = m.meal_type_code;

-- 5) Item kind flags + a single kind string
CREATE VIEW
    aether.v_item_kinds AS
SELECT
    i.item_id,
    (b.blob_id IS NOT NULL) AS is_ctb,
    (cl.item_id IS NOT NULL) AS is_clothes,
    (se.item_id IS NOT NULL) AS is_scientific_equipment,
    (sp.item_id IS NOT NULL) AS is_spare_part,
    (ms.item_id IS NOT NULL) AS is_medical_supply,
    (hy.item_id IS NOT NULL) AS is_hygiene_item,
    (wc.item_id IS NOT NULL) AS is_waste_container,
    CASE
        WHEN b.blob_id IS NOT NULL THEN 'CTB'
        WHEN cl.item_id IS NOT NULL THEN 'CLOTHES'
        WHEN se.item_id IS NOT NULL THEN 'SCIENTIFIC_EQUIPMENT'
        WHEN sp.item_id IS NOT NULL THEN 'SPARE_PART'
        WHEN ms.item_id IS NOT NULL THEN 'MEDICAL_SUPPLY'
        WHEN hy.item_id IS NOT NULL THEN 'HYGIENE_ITEM'
        WHEN wc.item_id IS NOT NULL THEN 'WASTE_CONTAINER'
        ELSE 'GENERIC'
    END AS item_kind
FROM
    aether.items i
    LEFT JOIN aether.blobs b ON b.blob_id = i.item_id
    LEFT JOIN aether.clothes cl ON cl.item_id = i.item_id
    LEFT JOIN aether.scientific_equipment se ON se.item_id = i.item_id
    LEFT JOIN aether.spare_parts sp ON sp.item_id = i.item_id
    LEFT JOIN aether.medical_supplies ms ON ms.item_id = i.item_id
    LEFT JOIN aether.hygiene_items hy ON hy.item_id = i.item_id
    LEFT JOIN aether.waste_containers wc ON wc.item_id = i.item_id;

-- 6) Catalog: item + owner + site + kind
CREATE VIEW
    aether.v_items_catalog AS
SELECT
    iwos.item_id,
    iwos.rfid,
    iwos.name,
    iwos.status,
    iwos.size_m3,
    iwos.mass_kg,
    ik.item_kind,
    iwos.owner_name,
    iwos.rack,
    iwos.shelf,
    iwos.depth
FROM
    aether.v_items_with_owner_site iwos
    LEFT JOIN aether.v_item_kinds ik ON ik.item_id = iwos.item_id;

-- 7) Effective site: climb to outermost CTB (or self)
CREATE VIEW
    aether.v_item_effective_site AS
WITH RECURSIVE
    chain AS (
        SELECT
            i.item_id,
            i.site_id,
            0 AS depth
        FROM
            aether.items i
        UNION ALL
        SELECT
            parent_i.item_id,
            parent_i.site_id,
            c.depth + 1
        FROM
            chain c
            JOIN aether.ctb_contents cc ON cc.child_item_id = c.item_id
            JOIN aether.blobs pb ON pb.blob_id = cc.parent_blob_id
            JOIN aether.items parent_i ON parent_i.item_id = pb.blob_id
    )
SELECT DISTINCT
    ON (item_id) item_id,
    site_id AS effective_site_id,
    depth AS hops_to_site
FROM
    chain
ORDER BY
    item_id,
    depth DESC;

-- 8) Effective location (rack/shelf/depth)
CREATE VIEW
    aether.v_item_effective_location AS
SELECT
    ies.item_id,
    s.rack,
    s.shelf,
    s.depth,
    ies.hops_to_site
FROM
    aether.v_item_effective_site ies
    JOIN aether.storage_sites s ON s.site_id = ies.effective_site_id;

-- 9) Meals with effective location
CREATE VIEW
    aether.v_meal_effective_location AS
SELECT
    m.meal_id,
    m.blob_id,
    m.slot,
    m.status,
    loc.rack,
    loc.shelf,
    loc.depth,
    t.label AS meal_label,
    t.kind AS meal_kind
FROM
    aether.meals m
    JOIN aether.v_item_effective_location loc ON loc.item_id = m.blob_id
    JOIN aether.meal_types t ON t.code = m.meal_type_code;
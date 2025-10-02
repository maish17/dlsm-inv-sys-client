-- 004_views.sql
SET
    search_path = aether,
    public;

CREATE
OR REPLACE VIEW aether.v_meals_with_type AS
SELECT
    m.meal_id,
    m.blob_id,
    m.slot,
    m.meal_type_code,
    t.kind AS meal_kind,
    t.label AS meal_label,
    m.is_special,
    m.expiration_date,
    m.status,
    t.energy_kcal,
    t.vit_a_mcg_rae,
    t.vit_b2_mg,
    t.vit_b3_mg,
    t.vit_b4_mg,
    t.vit_b5_mg,
    t.vit_b6_mg,
    t.vit_b7_mg,
    t.vit_b8_mg,
    t.vit_b9_mg,
    t.vit_b10_mg,
    t.vit_b11_mg,
    t.vit_b12_mg,
    m.created_at,
    m.updated_at
FROM
    aether.meals m
    JOIN aether.meal_types t ON t.code = m.meal_type_code;
SET
    search_path = aether,
    public;

INSERT INTO
    aether.meal_types (code, kind, label, energy_kcal, vit_a_mcg_rae)
VALUES
    (1, 'BASE', 'Breakfast', 500, 900),
    (2, 'BASE', 'Lunch', 650, 800),
    (3, 'BASE', 'Dinner', 700, 950),
    (4, 'BASE', 'Snack', 250, 100) ON CONFLICT (code) DO
UPDATE
SET
    kind = EXCLUDED.kind,
    label = EXCLUDED.label,
    energy_kcal = EXCLUDED.energy_kcal,
    vit_a_mcg_rae = EXCLUDED.vit_a_mcg_rae,
    updated_at = now ();
SET search_path = aether, public;

-- site
INSERT INTO aether.storage_sites(rack,shelf,depth)
VALUES ('RACK-A',1,1)
ON CONFLICT (rack,shelf,depth) DO NOTHING;

-- users
INSERT INTO aether.users(full_name, email) VALUES ('Person A','a@example.com') ON CONFLICT DO NOTHING;
INSERT INTO aether.users(full_name, email) VALUES ('Person B','b@example.com') ON CONFLICT DO NOTHING;

-- item using enum status
WITH s AS (
  SELECT site_id FROM aether.storage_sites WHERE rack='RACK-A' AND shelf=1 AND depth=1
)
INSERT INTO aether.items(name, site_id, status)
SELECT 'Demo Item', site_id, 'ACTIVE'::aether.item_status FROM s
RETURNING item_id, status;

-- meal catalog using enum kind
INSERT INTO aether.meal_types(code, kind, label, energy_kcal)
VALUES (42, 'BASE', 'Baseline Meal', 600)
ON CONFLICT (code) DO UPDATE SET label=EXCLUDED.label
RETURNING code, kind;

-- quick select to show types applied
TABLE aether.items LIMIT 1;
TABLE aether.meal_types LIMIT 1;
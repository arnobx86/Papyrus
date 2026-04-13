-- 1. Make shop_id nullable to allow for Global Roles (system roles)
ALTER TABLE roles ALTER COLUMN shop_id DROP NOT NULL;

-- 2. Ensure 'name' is unique globally for system roles (NULL shop_id)
-- We use a partial index or just a global unique for simple roles
DO $$ 
BEGIN 
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'roles_name_key') THEN
    ALTER TABLE roles ADD CONSTRAINT roles_name_key UNIQUE (name);
  END IF;
END $$;

-- 3. Seed roles for Papyrus Business Suite
INSERT INTO roles (name)
VALUES 
  ('Owner'),
  ('Manager'),
  ('Sales Representative'),
  ('Inventory Staff')
ON CONFLICT (name) DO NOTHING;

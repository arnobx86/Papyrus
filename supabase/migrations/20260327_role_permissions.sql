-- 1. Add permissions column to roles table
ALTER TABLE roles ADD COLUMN IF NOT EXISTS permissions JSONB DEFAULT '{}'::jsonB;

-- 2. Update Roles with default permissions from screenshots
-- Owner
UPDATE roles SET permissions = '{
  "create_sale": true, "edit_sale": true, "delete_sale": true,
  "create_purchase": true, "edit_purchase": true, "delete_purchase": true,
  "manage_products": true, "manage_stock": true,
  "manage_customers": true, "manage_suppliers": true,
  "view_reports": true, "manage_employees": true, "manage_roles": true, "approve_actions": true
}'::jsonb WHERE name = 'Owner';

-- Manager
UPDATE roles SET permissions = '{
  "create_sale": true, "edit_sale": true, "delete_sale": false,
  "create_purchase": true, "edit_purchase": true, "delete_purchase": false,
  "manage_products": true, "manage_stock": true,
  "manage_customers": true, "manage_suppliers": true,
  "view_reports": true, "manage_employees": true, "manage_roles": false, "approve_actions": true
}'::jsonb WHERE name = 'Manager';

-- Sales Representative
UPDATE roles SET permissions = '{
  "create_sale": true, "edit_sale": false, "delete_sale": false,
  "create_purchase": false, "edit_purchase": false, "delete_purchase": false,
  "manage_products": false, "manage_stock": true,
  "manage_customers": true, "manage_suppliers": false,
  "view_reports": false, "manage_employees": false, "manage_roles": false, "approve_actions": false
}'::jsonb WHERE name = 'Sales Representative';

-- Inventory Staff
UPDATE roles SET permissions = '{
  "create_sale": false, "edit_sale": false, "delete_sale": false,
  "create_purchase": true, "edit_purchase": false, "delete_purchase": false,
  "manage_products": true, "manage_stock": true,
  "manage_customers": false, "manage_suppliers": true,
  "view_reports": false, "manage_employees": false, "manage_roles": false, "approve_actions": false
}'::jsonb WHERE name = 'Inventory Staff';

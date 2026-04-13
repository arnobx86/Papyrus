-- 🚀 PAPYRUS TRIGGER CLEANUP
-- This script removes duplicate/legacy triggers that cause stock to be updated twice.
-- The user reported that purchasing 10 adds 20 to the stock.

-- 1. Drop old triggers from purchase_items
DROP TRIGGER IF EXISTS trg_purchase_stock_update ON purchase_items;
DROP TRIGGER IF EXISTS trg_purchase_stock_v2 ON purchase_items;

-- 2. Drop old triggers from sale_items
DROP TRIGGER IF EXISTS trg_sale_stock_update ON sale_items;
DROP TRIGGER IF EXISTS trg_sale_stock_v2 ON sale_items;

-- 3. Drop old triggers from returns
DROP TRIGGER IF EXISTS trg_returns_stock_update ON returns;

-- 4. Clean up legacy functions
DROP FUNCTION IF EXISTS update_stock_from_transaction_items() CASCADE;

-- 5. Re-assert the final integrity trigger function name (consistency)
-- The current function in 20260401_business_integrity_triggers.sql is handle_stock_operation()
-- and trigger is trg_purchase_stock. This is the one we keep.

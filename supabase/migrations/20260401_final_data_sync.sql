-- 🚀 PAPYRUS FINAL DATA HARMONIZATION
-- This script ensures all existing products have their prices correctly synced.
-- It resolves the issue where "purchase price is not showing" by unifying columns.

-- 1. Ensure columns exist (safety check)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'purchase_price') THEN
        ALTER TABLE products ADD COLUMN purchase_price NUMERIC DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'cost_price') THEN
        ALTER TABLE products ADD COLUMN cost_price NUMERIC DEFAULT 0;
    END IF;
END $$;

-- 2. Sync data across different price columns (Harmonization)
UPDATE products 
SET 
  purchase_price = COALESCE(purchase_price, cost_price, 0),
  cost_price = COALESCE(cost_price, purchase_price, 0)
WHERE purchase_price IS NULL OR cost_price IS NULL OR purchase_price = 0 OR cost_price = 0;

-- 3. Ensure all products have a sale_price (renamed from price)
UPDATE products SET sale_price = 0 WHERE sale_price IS NULL;

-- 4. Fix any potential duplication in activity_logs RLS
DROP POLICY IF EXISTS "activity_logs_insert" ON activity_logs;
CREATE POLICY "activity_logs_insert" ON activity_logs FOR INSERT TO authenticated WITH CHECK (true); -- Allow all authenticated to log to their shops

-- 5. Final check on stock triggers (Ensuring ONLY one exists)
DROP TRIGGER IF EXISTS trg_purchase_stock_update ON purchase_items;
DROP TRIGGER IF EXISTS trg_sale_stock_update ON sale_items;
DROP TRIGGER IF EXISTS trg_purchase_stock ON purchase_items;
CREATE TRIGGER trg_purchase_stock AFTER INSERT OR DELETE ON purchase_items FOR EACH ROW EXECUTE FUNCTION handle_stock_operation();

-- Safely unify the products table column names
DO $$
BEGIN
    -- Rename 'price' to 'sale_price' only if 'price' exists and 'sale_price' does not
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'price') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'sale_price') THEN
        ALTER TABLE products RENAME COLUMN price TO sale_price;
    END IF;

    -- Ensure defaults are set for all core columns
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'sale_price') THEN
        ALTER TABLE products ALTER COLUMN sale_price SET DEFAULT 0;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'purchase_price') THEN
        ALTER TABLE products ALTER COLUMN purchase_price SET DEFAULT 0;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'stock') THEN
        ALTER TABLE products ALTER COLUMN stock SET DEFAULT 0;
    END IF;
END $$;

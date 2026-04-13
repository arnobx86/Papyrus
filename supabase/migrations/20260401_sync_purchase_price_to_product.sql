-- 🚀 PAPYRUS AUTOMATIC PURCHASE PRICE SYNC
-- This migration updates the existing stock handler to AUTOMATICALLY update 
-- the product's Purchase Price whenever a new Purchase is recorded.

CREATE OR REPLACE FUNCTION handle_stock_operation()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_TABLE_NAME = 'purchase_items') THEN
        IF (TG_OP = 'INSERT') THEN
            -- Update stock AND automatically sync the new purchase price
            UPDATE products 
            SET 
                stock = stock + NEW.quantity,
                purchase_price = NEW.price,
                cost_price = NEW.price -- Sync both for safety
            WHERE id = NEW.product_id;
        ELSIF (TG_OP = 'DELETE') THEN
            UPDATE products SET stock = stock - OLD.quantity WHERE id = OLD.product_id;
        END IF;
    ELSIF (TG_TABLE_NAME = 'sale_items') THEN
        IF (TG_OP = 'INSERT') THEN
            UPDATE products SET stock = stock - NEW.quantity WHERE id = NEW.product_id;
        ELSIF (TG_OP = 'DELETE') THEN
            UPDATE products SET stock = stock + OLD.quantity WHERE id = OLD.product_id;
        END IF;
    ELSIF (TG_TABLE_NAME = 'returns') THEN
        IF (TG_OP = 'INSERT') THEN
            IF (NEW.type = 'sale') THEN
                UPDATE products SET stock = stock + COALESCE(NEW.quantity, 0) WHERE id = NEW.product_id;
            ELSIF (NEW.type = 'purchase') THEN
                UPDATE products SET stock = stock - COALESCE(NEW.quantity, 0) WHERE id = NEW.product_id;
            END IF;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- No need to recreate triggers, just updating the function is enough.

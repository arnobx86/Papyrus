-- 🚀 PAPYRUS BACKFILL PURCHASE PRICES
-- This script finds the LATEST purchase price for every product 
-- and updates the product catalog to reflect those prices.

DO $$
BEGIN
    -- Update purchase_price and cost_price from the most recent purchase_item
    UPDATE products p
    SET 
        purchase_price = pi.price,
        cost_price = pi.price
    FROM (
        -- Subquery to get the newest price for each product
        SELECT DISTINCT ON (product_id) 
            product_id, 
            price 
        FROM purchase_items 
        ORDER BY product_id, created_at DESC
    ) pi
    WHERE p.id = pi.product_id 
    AND (p.purchase_price IS NULL OR p.purchase_price = 0);

END $$;

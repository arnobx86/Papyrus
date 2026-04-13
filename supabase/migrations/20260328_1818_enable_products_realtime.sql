-- Enable Realtime for business tables
-- This allows real-time subscriptions to receive updates when data changes

-- Add products table to the supabase_realtime publication
alter publication supabase_realtime add table products;

-- Add purchases table to the supabase_realtime publication
alter publication supabase_realtime add table purchases;

-- Add sales table to the supabase_realtime publication
alter publication supabase_realtime add table sales;

-- Add returns table to the supabase_realtime publication
alter publication supabase_realtime add table returns;

-- Verify the tables are in the publication
-- (Optional) You can run: SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename IN ('products', 'purchases', 'sales', 'returns');
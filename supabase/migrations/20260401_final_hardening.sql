-- 🚀 PAPYRUS FINAL SYSTEM HARDENING
-- 1. Profiles Table RLS (Public Visibility for names/usernames)
-- 2. Transaction Linking Schema (Linking money to Invoices)

-- =============================================
-- PROFILES RLS (Allow reading by anyone)
-- =============================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON profiles;
CREATE POLICY "Profiles are viewable by everyone" 
ON profiles FOR SELECT 
USING ( true );

DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
CREATE POLICY "Users can update their own profile" 
ON profiles FOR UPDATE 
USING ( auth.uid() = id );

-- =============================================
-- TRANSACTION LINKING SCHEMA (SAFE ADDITION)
-- =============================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'transactions' AND column_name = 'reference_id') THEN
        ALTER TABLE transactions ADD COLUMN reference_id UUID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'transactions' AND column_name = 'reference_type') THEN
        ALTER TABLE transactions ADD COLUMN reference_type TEXT; -- 'sale', 'purchase', 'manual'
    END IF;
END $$;

-- Index for deletions (Safe creation)
CREATE INDEX IF NOT EXISTS idx_transactions_reference ON transactions(reference_id, reference_type);

-- Notify users
COMMENT ON TABLE profiles IS 'User profiles. Publicly readable to allow team/member search.';
COMMENT ON COLUMN transactions.reference_id IS 'UUID of the sale or purchase invoice this transaction belongs to.';

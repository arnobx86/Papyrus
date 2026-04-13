-- 🚀 PAPYRUS SCHEMA UNIFICATION
-- Standardizing 'approval_requests' table columns to match Flutter app expectations.

DO $$
BEGIN
    -- Rename 'type' to 'action_type' if it exists and 'action_type' doesn't
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'approval_requests' AND column_name = 'type') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'approval_requests' AND column_name = 'action_type') THEN
        ALTER TABLE approval_requests RENAME COLUMN type TO action_type;
    END IF;

    -- Rename 'requester_id' to 'requested_by' if it exists and 'requested_by' doesn't
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'approval_requests' AND column_name = 'requester_id') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'approval_requests' AND column_name = 'requested_by') THEN
        ALTER TABLE approval_requests RENAME COLUMN requester_id TO requested_by;
    END IF;

    -- Add 'reference_id' and 'approved_by' if they don't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'approval_requests' AND column_name = 'reference_id') THEN
        ALTER TABLE approval_requests ADD COLUMN reference_id UUID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'approval_requests' AND column_name = 'approved_by') THEN
        ALTER TABLE approval_requests ADD COLUMN approved_by UUID REFERENCES auth.users(id);
    END IF;
    
    -- Ensure status column exists (it should, but just in case)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'approval_requests' AND column_name = 'status') THEN
        ALTER TABLE approval_requests ADD COLUMN status TEXT DEFAULT 'pending';
    END IF;
    
    -- Ensure details column exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'approval_requests' AND column_name = 'details') THEN
        ALTER TABLE approval_requests ADD COLUMN details JSONB DEFAULT '{}'::JSONB;
    END IF;

END $$;

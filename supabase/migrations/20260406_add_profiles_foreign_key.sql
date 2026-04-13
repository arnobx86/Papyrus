-- Add foreign key relationship between approval_requests and profiles
-- This enables PostgREST join queries to fetch requester information

-- First, ensure the requested_by column exists
DO $$
BEGIN
    -- Check if requested_by column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'approval_requests' 
        AND column_name = 'requested_by'
    ) THEN
        -- If requested_by doesn't exist, check for requester_id and rename it
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'approval_requests' 
            AND column_name = 'requester_id'
        ) THEN
            ALTER TABLE approval_requests RENAME COLUMN requester_id TO requested_by;
            RAISE NOTICE 'Renamed requester_id to requested_by in approval_requests table';
        ELSE
            RAISE EXCEPTION 'Neither requested_by nor requester_id column exists in approval_requests table';
        END IF;
    END IF;
END $$;

-- Add foreign key constraint if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'public' 
        AND table_name = 'approval_requests' 
        AND constraint_name = 'fk_approval_requests_requested_by'
    ) THEN
        ALTER TABLE approval_requests 
        ADD CONSTRAINT fk_approval_requests_requested_by 
        FOREIGN KEY (requested_by) REFERENCES profiles(id)
        ON DELETE SET NULL;
        RAISE NOTICE 'Added foreign key constraint fk_approval_requests_requested_by on approval_requests(requested_by) referencing profiles(id)';
    ELSE
        RAISE NOTICE 'Foreign key constraint fk_approval_requests_requested_by already exists';
    END IF;
END $$;

-- Create index on requested_by for better query performance
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'public' 
        AND tablename = 'approval_requests' 
        AND indexname = 'idx_approval_requests_requested_by'
    ) THEN
        CREATE INDEX idx_approval_requests_requested_by ON approval_requests(requested_by);
        RAISE NOTICE 'Created index idx_approval_requests_requested_by on approval_requests(requested_by)';
    END IF;
END $$;

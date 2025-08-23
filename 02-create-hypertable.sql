-- Convert all time-series tables to hypertables
-- Note: This script will be executed with search_path set to the appropriate schema

-- Try to create hypertables if tables exist (using IF NOT EXISTS equivalent)
DO $$
BEGIN
    -- Check if user_locations table exists and create hypertable
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_locations') THEN
        PERFORM create_hypertable('user_locations', 'timestamp', if_not_exists => TRUE);
        RAISE NOTICE 'Created hypertable for user_locations';
    END IF;
    
    -- Check if emergency_alerts table exists and create hypertable
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'emergency_alerts') THEN
        PERFORM create_hypertable('emergency_alerts', 'timestamp', if_not_exists => TRUE);
        RAISE NOTICE 'Created hypertable for emergency_alerts';
    END IF;
    
    -- Check if payment_transactions table exists and create hypertable
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'payment_transactions') THEN
        PERFORM create_hypertable('payment_transactions', 'timestamp', if_not_exists => TRUE);
        RAISE NOTICE 'Created hypertable for payment_transactions';
    END IF;
    
    -- Check if event_messages table exists and create hypertable
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'event_messages') THEN
        PERFORM create_hypertable('event_messages', 'timestamp', if_not_exists => TRUE);
        RAISE NOTICE 'Created hypertable for event_messages';
    END IF;
    
    -- Check if event_updates table exists and create hypertable
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'event_updates') THEN
        PERFORM create_hypertable('event_updates', 'timestamp', if_not_exists => TRUE);
        RAISE NOTICE 'Created hypertable for event_updates';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Hypertable creation skipped or failed: %', SQLERRM;
END $$; 
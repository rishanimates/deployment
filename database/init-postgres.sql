-- ============================================================================
-- PostgreSQL Database Initialization Script
-- ============================================================================
-- This script creates all tables, indexes, and initial data for all services
-- Services: auth-service, user-service, event-service, shared-service
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Set timezone
SET timezone = 'UTC';

-- ============================================================================
-- USERS SCHEMA (auth-service, user-service)
-- ============================================================================

-- Users table
CREATE TABLE IF NOT EXISTS users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    bio TEXT,
    avatar_url TEXT,
    birth_date DATE,
    is_email_verified BOOLEAN DEFAULT FALSE,
    is_phone_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Groups table
CREATE TABLE IF NOT EXISTS groups (
    group_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    avatar_url TEXT,
    is_private BOOLEAN DEFAULT FALSE,
    settings JSONB DEFAULT '{}'::jsonb
);

-- Group memberships
CREATE TABLE IF NOT EXISTS group_memberships (
    group_id TEXT NOT NULL REFERENCES groups(group_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    invited_by UUID REFERENCES users(user_id),
    PRIMARY KEY (group_id, user_id)
);

-- Invitations (user and group)
CREATE TABLE IF NOT EXISTS invitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    recipient_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    recipient_email TEXT,
    group_id TEXT REFERENCES groups(group_id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('user', 'group')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'expired')),
    token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Stories
CREATE TABLE IF NOT EXISTS stories (
    story_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    media_url TEXT NOT NULL,
    media_type TEXT NOT NULL CHECK (media_type IN ('image', 'video')),
    caption TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
    is_private BOOLEAN DEFAULT FALSE,
    view_count INTEGER DEFAULT 0
);

-- Story views
CREATE TABLE IF NOT EXISTS story_views (
    story_id UUID NOT NULL REFERENCES stories(story_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (story_id, user_id)
);

-- ============================================================================
-- EVENTS SCHEMA (event-service)
-- ============================================================================

-- Events table
CREATE TABLE IF NOT EXISTS events (
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    location TEXT,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ,
    created_by UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    max_participants INTEGER,
    is_private BOOLEAN DEFAULT FALSE,
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'completed')),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Event participants
CREATE TABLE IF NOT EXISTS event_participants (
    event_id UUID NOT NULL REFERENCES events(event_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'participant' CHECK (role IN ('organizer', 'participant', 'invited')),
    status VARCHAR(50) DEFAULT 'confirmed' CHECK (status IN ('invited', 'confirmed', 'declined', 'maybe')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (event_id, user_id)
);

-- Event updates
CREATE TABLE IF NOT EXISTS event_updates (
    update_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(event_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    update_type VARCHAR(50) NOT NULL CHECK (update_type IN ('announcement', 'location_change', 'time_change', 'cancellation')),
    title VARCHAR(255) NOT NULL,
    content TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- EXPENSES SCHEMA (splitz-service - stored in PostgreSQL for consistency)
-- ============================================================================

-- Expenses table
CREATE TABLE IF NOT EXISTS expenses (
    expense_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    amount DECIMAL(12, 2) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) DEFAULT 'USD',
    category VARCHAR(100),
    paid_by UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    group_id TEXT REFERENCES groups(group_id) ON DELETE CASCADE,
    receipt_url TEXT,
    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Expense splits
CREATE TABLE IF NOT EXISTS expense_splits (
    split_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    expense_id UUID NOT NULL REFERENCES expenses(expense_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    amount DECIMAL(12, 2) NOT NULL CHECK (amount >= 0),
    is_settled BOOLEAN DEFAULT FALSE,
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Expense categories (default categories)
CREATE TABLE IF NOT EXISTS expense_categories (
    category_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) UNIQUE NOT NULL,
    icon VARCHAR(50),
    color VARCHAR(7),
    is_default BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- NOTIFICATIONS SCHEMA (shared-service)
-- ============================================================================

-- Notifications table
CREATE TABLE IF NOT EXISTS notifications (
    notification_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('event', 'expense', 'group', 'story', 'system')),
    data JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Push notification tokens
CREATE TABLE IF NOT EXISTS push_tokens (
    token_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform VARCHAR(20) NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, token)
);

-- ============================================================================
-- FILE STORAGE SCHEMA (shared-service)
-- ============================================================================

-- File uploads table
CREATE TABLE IF NOT EXISTS file_uploads (
    file_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    original_name VARCHAR(255) NOT NULL,
    filename VARCHAR(255) NOT NULL,
    file_path TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    file_type VARCHAR(50) NOT NULL CHECK (file_type IN ('image', 'video', 'document', 'audio', 'other')),
    upload_source VARCHAR(50) DEFAULT 'app' CHECK (upload_source IN ('app', 'web', 'api')),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- CHAT SCHEMA (chat-service)
-- ============================================================================

-- Chat rooms
CREATE TABLE IF NOT EXISTS chat_rooms (
    room_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255),
    type VARCHAR(20) NOT NULL DEFAULT 'group' CHECK (type IN ('direct', 'group')),
    group_id TEXT REFERENCES groups(group_id) ON DELETE CASCADE,
    created_by UUID REFERENCES users(user_id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Chat participants
CREATE TABLE IF NOT EXISTS chat_participants (
    room_id UUID NOT NULL REFERENCES chat_rooms(room_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('admin', 'member')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_read_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (room_id, user_id)
);

-- Chat messages
CREATE TABLE IF NOT EXISTS chat_messages (
    message_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES chat_rooms(room_id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file', 'system')),
    file_id UUID REFERENCES file_uploads(file_id),
    metadata JSONB DEFAULT '{}'::jsonb,
    is_edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Users indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users (created_at);
CREATE INDEX IF NOT EXISTS idx_users_last_login ON users (last_login_at);

-- Groups indexes
CREATE INDEX IF NOT EXISTS idx_groups_created_by ON groups (created_by);
CREATE INDEX IF NOT EXISTS idx_groups_created_at ON groups (created_at);

-- Group memberships indexes
CREATE INDEX IF NOT EXISTS idx_group_memberships_group ON group_memberships (group_id);
CREATE INDEX IF NOT EXISTS idx_group_memberships_user ON group_memberships (user_id);
CREATE INDEX IF NOT EXISTS idx_group_memberships_role ON group_memberships (role);

-- Invitations indexes
CREATE INDEX IF NOT EXISTS idx_invitations_sender ON invitations (sender_id);
CREATE INDEX IF NOT EXISTS idx_invitations_recipient ON invitations (recipient_id);
CREATE INDEX IF NOT EXISTS idx_invitations_group ON invitations (group_id);
CREATE INDEX IF NOT EXISTS idx_invitations_token ON invitations (token);
CREATE INDEX IF NOT EXISTS idx_invitations_status ON invitations (status);
CREATE INDEX IF NOT EXISTS idx_invitations_expires_at ON invitations (expires_at);

-- Stories indexes
CREATE INDEX IF NOT EXISTS idx_stories_user ON stories (user_id);
CREATE INDEX IF NOT EXISTS idx_stories_created_at ON stories (created_at);
CREATE INDEX IF NOT EXISTS idx_stories_expires_at ON stories (expires_at);

-- Story views indexes
CREATE INDEX IF NOT EXISTS idx_story_views_story ON story_views (story_id);
CREATE INDEX IF NOT EXISTS idx_story_views_user ON story_views (user_id);
CREATE INDEX IF NOT EXISTS idx_story_views_viewed_at ON story_views (viewed_at);

-- Events indexes
CREATE INDEX IF NOT EXISTS idx_events_created_by ON events (created_by);
CREATE INDEX IF NOT EXISTS idx_events_start_date ON events (start_date);
CREATE INDEX IF NOT EXISTS idx_events_status ON events (status);
CREATE INDEX IF NOT EXISTS idx_events_created_at ON events (created_at);

-- Event participants indexes
CREATE INDEX IF NOT EXISTS idx_event_participants_event ON event_participants (event_id);
CREATE INDEX IF NOT EXISTS idx_event_participants_user ON event_participants (user_id);
CREATE INDEX IF NOT EXISTS idx_event_participants_role ON event_participants (role);
CREATE INDEX IF NOT EXISTS idx_event_participants_status ON event_participants (status);

-- Event updates indexes
CREATE INDEX IF NOT EXISTS idx_event_updates_event ON event_updates (event_id);
CREATE INDEX IF NOT EXISTS idx_event_updates_user ON event_updates (user_id);
CREATE INDEX IF NOT EXISTS idx_event_updates_created_at ON event_updates (created_at);

-- Expenses indexes
CREATE INDEX IF NOT EXISTS idx_expenses_paid_by ON expenses (paid_by);
CREATE INDEX IF NOT EXISTS idx_expenses_group ON expenses (group_id);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses (date);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses (category);
CREATE INDEX IF NOT EXISTS idx_expenses_created_at ON expenses (created_at);

-- Expense splits indexes
CREATE INDEX IF NOT EXISTS idx_expense_splits_expense ON expense_splits (expense_id);
CREATE INDEX IF NOT EXISTS idx_expense_splits_user ON expense_splits (user_id);
CREATE INDEX IF NOT EXISTS idx_expense_splits_settled ON expense_splits (is_settled);

-- Notifications indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications (user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications (type);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications (is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications (created_at);

-- Push tokens indexes
CREATE INDEX IF NOT EXISTS idx_push_tokens_user ON push_tokens (user_id);
CREATE INDEX IF NOT EXISTS idx_push_tokens_platform ON push_tokens (platform);
CREATE INDEX IF NOT EXISTS idx_push_tokens_active ON push_tokens (is_active);

-- File uploads indexes
CREATE INDEX IF NOT EXISTS idx_file_uploads_user ON file_uploads (user_id);
CREATE INDEX IF NOT EXISTS idx_file_uploads_type ON file_uploads (file_type);
CREATE INDEX IF NOT EXISTS idx_file_uploads_created_at ON file_uploads (created_at);

-- Chat rooms indexes
CREATE INDEX IF NOT EXISTS idx_chat_rooms_type ON chat_rooms (type);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_group ON chat_rooms (group_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_created_by ON chat_rooms (created_by);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_active ON chat_rooms (is_active);

-- Chat participants indexes
CREATE INDEX IF NOT EXISTS idx_chat_participants_room ON chat_participants (room_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_user ON chat_participants (user_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_role ON chat_participants (role);

-- Chat messages indexes
CREATE INDEX IF NOT EXISTS idx_chat_messages_room ON chat_messages (room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON chat_messages (sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_type ON chat_messages (message_type);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages (created_at);

-- ============================================================================
-- DEFAULT DATA
-- ============================================================================

-- Insert default expense categories
INSERT INTO expense_categories (name, icon, color, is_default) VALUES
    ('Food & Dining', '🍽️', '#FF6B6B', true),
    ('Transportation', '🚗', '#4ECDC4', true),
    ('Entertainment', '🎬', '#45B7D1', true),
    ('Shopping', '🛍️', '#96CEB4', true),
    ('Utilities', '💡', '#FFEAA7', true),
    ('Healthcare', '🏥', '#DDA0DD', true),
    ('Travel', '✈️', '#74B9FF', true),
    ('Education', '📚', '#A29BFE', true),
    ('Other', '📦', '#636E72', true)
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- FUNCTIONS AND TRIGGERS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers to relevant tables
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_invitations_updated_at ON invitations;
CREATE TRIGGER update_invitations_updated_at BEFORE UPDATE ON invitations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_events_updated_at ON events;
CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_expenses_updated_at ON expenses;
CREATE TRIGGER update_expenses_updated_at BEFORE UPDATE ON expenses 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_push_tokens_updated_at ON push_tokens;
CREATE TRIGGER update_push_tokens_updated_at BEFORE UPDATE ON push_tokens 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_chat_rooms_updated_at ON chat_rooms;
CREATE TRIGGER update_chat_rooms_updated_at BEFORE UPDATE ON chat_rooms 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ PostgreSQL database initialization completed successfully!';
    RAISE NOTICE '📊 Created tables: users, groups, group_memberships, invitations, stories, story_views, events, event_participants, event_updates, expenses, expense_splits, expense_categories, notifications, push_tokens, file_uploads, chat_rooms, chat_participants, chat_messages';
    RAISE NOTICE '🔍 Created indexes: 50+ performance indexes on all tables';
    RAISE NOTICE '⚡ Created triggers: Auto-update timestamps on 6 tables';
    RAISE NOTICE '📦 Inserted default data: 9 expense categories';
    RAISE NOTICE '🎉 Database is ready for all services!';
END $$;

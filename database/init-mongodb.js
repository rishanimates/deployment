// ============================================================================
// MongoDB Database Initialization Script
// ============================================================================
// This script creates all collections, indexes, and initial data for MongoDB
// Services: splitz-service (alternative), chat-service (alternative)
// ============================================================================

// Switch to the letzgo database
db = db.getSiblingDB('letzgo');

print('🚀 Starting MongoDB initialization...');

// ============================================================================
// COLLECTIONS SETUP
// ============================================================================

// Create collections if they don't exist
const collections = [
    'expenses',
    'expense_splits', 
    'expense_categories',
    'chat_rooms',
    'chat_messages',
    'chat_participants'
];

collections.forEach(collectionName => {
    if (!db.getCollectionNames().includes(collectionName)) {
        db.createCollection(collectionName);
        print(`✅ Created collection: ${collectionName}`);
    } else {
        print(`ℹ️  Collection already exists: ${collectionName}`);
    }
});

// ============================================================================
// EXPENSES SCHEMA (Alternative to PostgreSQL)
// ============================================================================

// Create expenses collection with validation
db.runCommand({
    collMod: 'expenses',
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['title', 'amount', 'paid_by', 'date'],
            properties: {
                _id: { bsonType: 'objectId' },
                title: { bsonType: 'string', minLength: 1, maxLength: 255 },
                description: { bsonType: 'string' },
                amount: { bsonType: 'number', minimum: 0 },
                currency: { bsonType: 'string', minLength: 3, maxLength: 3 },
                category: { bsonType: 'string' },
                paid_by: { bsonType: 'string' }, // UUID as string
                group_id: { bsonType: 'string' },
                receipt_url: { bsonType: 'string' },
                date: { bsonType: 'date' },
                created_at: { bsonType: 'date' },
                updated_at: { bsonType: 'date' }
            }
        }
    },
    validationAction: 'warn'
});

// Create expense_splits collection with validation
db.runCommand({
    collMod: 'expense_splits',
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['expense_id', 'user_id', 'amount'],
            properties: {
                _id: { bsonType: 'objectId' },
                expense_id: { bsonType: 'objectId' },
                user_id: { bsonType: 'string' }, // UUID as string
                amount: { bsonType: 'number', minimum: 0 },
                is_settled: { bsonType: 'bool' },
                settled_at: { bsonType: 'date' },
                created_at: { bsonType: 'date' }
            }
        }
    },
    validationAction: 'warn'
});

// ============================================================================
// CHAT SCHEMA (Alternative to PostgreSQL)
// ============================================================================

// Create chat_rooms collection with validation
db.runCommand({
    collMod: 'chat_rooms',
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['type'],
            properties: {
                _id: { bsonType: 'objectId' },
                name: { bsonType: 'string' },
                type: { enum: ['direct', 'group'] },
                group_id: { bsonType: 'string' },
                created_by: { bsonType: 'string' }, // UUID as string
                is_active: { bsonType: 'bool' },
                metadata: { bsonType: 'object' },
                created_at: { bsonType: 'date' },
                updated_at: { bsonType: 'date' }
            }
        }
    },
    validationAction: 'warn'
});

// Create chat_messages collection with validation
db.runCommand({
    collMod: 'chat_messages',
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['room_id', 'sender_id', 'content'],
            properties: {
                _id: { bsonType: 'objectId' },
                room_id: { bsonType: 'objectId' },
                sender_id: { bsonType: 'string' }, // UUID as string
                content: { bsonType: 'string', minLength: 1 },
                message_type: { enum: ['text', 'image', 'file', 'system'] },
                file_id: { bsonType: 'string' },
                metadata: { bsonType: 'object' },
                is_edited: { bsonType: 'bool' },
                edited_at: { bsonType: 'date' },
                created_at: { bsonType: 'date' }
            }
        }
    },
    validationAction: 'warn'
});

// ============================================================================
// INDEXES FOR PERFORMANCE
// ============================================================================

print('📊 Creating indexes...');

// Expenses indexes
db.expenses.createIndex({ 'paid_by': 1 }, { background: true });
db.expenses.createIndex({ 'group_id': 1 }, { background: true });
db.expenses.createIndex({ 'date': -1 }, { background: true });
db.expenses.createIndex({ 'category': 1 }, { background: true });
db.expenses.createIndex({ 'created_at': -1 }, { background: true });
db.expenses.createIndex({ 'paid_by': 1, 'date': -1 }, { background: true });
db.expenses.createIndex({ 'group_id': 1, 'date': -1 }, { background: true });

// Expense splits indexes
db.expense_splits.createIndex({ 'expense_id': 1 }, { background: true });
db.expense_splits.createIndex({ 'user_id': 1 }, { background: true });
db.expense_splits.createIndex({ 'is_settled': 1 }, { background: true });
db.expense_splits.createIndex({ 'expense_id': 1, 'user_id': 1 }, { unique: true, background: true });

// Chat rooms indexes
db.chat_rooms.createIndex({ 'type': 1 }, { background: true });
db.chat_rooms.createIndex({ 'group_id': 1 }, { background: true });
db.chat_rooms.createIndex({ 'created_by': 1 }, { background: true });
db.chat_rooms.createIndex({ 'is_active': 1 }, { background: true });
db.chat_rooms.createIndex({ 'updated_at': -1 }, { background: true });

// Chat participants indexes
db.chat_participants.createIndex({ 'room_id': 1 }, { background: true });
db.chat_participants.createIndex({ 'user_id': 1 }, { background: true });
db.chat_participants.createIndex({ 'room_id': 1, 'user_id': 1 }, { unique: true, background: true });

// Chat messages indexes
db.chat_messages.createIndex({ 'room_id': 1 }, { background: true });
db.chat_messages.createIndex({ 'sender_id': 1 }, { background: true });
db.chat_messages.createIndex({ 'created_at': -1 }, { background: true });
db.chat_messages.createIndex({ 'room_id': 1, 'created_at': -1 }, { background: true });
db.chat_messages.createIndex({ 'message_type': 1 }, { background: true });

print('✅ Indexes created successfully');

// ============================================================================
// DEFAULT DATA
// ============================================================================

print('📦 Inserting default data...');

// Insert default expense categories
const defaultCategories = [
    { name: 'Food & Dining', icon: '🍽️', color: '#FF6B6B', is_default: true },
    { name: 'Transportation', icon: '🚗', color: '#4ECDC4', is_default: true },
    { name: 'Entertainment', icon: '🎬', color: '#45B7D1', is_default: true },
    { name: 'Shopping', icon: '🛍️', color: '#96CEB4', is_default: true },
    { name: 'Utilities', icon: '💡', color: '#FFEAA7', is_default: true },
    { name: 'Healthcare', icon: '🏥', color: '#DDA0DD', is_default: true },
    { name: 'Travel', icon: '✈️', color: '#74B9FF', is_default: true },
    { name: 'Education', icon: '📚', color: '#A29BFE', is_default: true },
    { name: 'Other', icon: '📦', color: '#636E72', is_default: true }
];

defaultCategories.forEach(category => {
    const existing = db.expense_categories.findOne({ name: category.name });
    if (!existing) {
        category.created_at = new Date();
        db.expense_categories.insertOne(category);
        print(`✅ Inserted category: ${category.name}`);
    } else {
        print(`ℹ️  Category already exists: ${category.name}`);
    }
});

// ============================================================================
// DATABASE STATISTICS
// ============================================================================

print('📊 Database Statistics:');
print(`📁 Collections: ${db.getCollectionNames().length}`);

db.getCollectionNames().forEach(name => {
    const count = db[name].countDocuments();
    const indexes = db[name].getIndexes().length;
    print(`   ${name}: ${count} documents, ${indexes} indexes`);
});

// ============================================================================
// COMPLETION MESSAGE
// ============================================================================

print('');
print('✅ MongoDB database initialization completed successfully!');
print('📊 Created collections: expenses, expense_splits, expense_categories, chat_rooms, chat_messages, chat_participants');
print('🔍 Created indexes: 20+ performance indexes on all collections');
print('📦 Inserted default data: 9 expense categories');
print('🎉 Database is ready for all services!');
print('');

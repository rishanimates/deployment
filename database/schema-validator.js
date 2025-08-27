// ============================================================================
// Database Schema Validator and Auto-Creator
// ============================================================================
// This script validates and creates database schemas on service startup
// Usage: node schema-validator.js <service-name> <database-type>
// Example: node schema-validator.js auth-service postgresql
// ============================================================================

const { Pool } = require('pg');
const { MongoClient } = require('mongodb');
const fs = require('fs').promises;
const path = require('path');

// Configuration
const config = {
    postgresql: {
        host: process.env.POSTGRES_HOST || 'postgres',
        port: process.env.POSTGRES_PORT || 5432,
        database: process.env.POSTGRES_DATABASE || 'letzgo',
        user: process.env.POSTGRES_USERNAME || 'letzgo',
        password: process.env.POSTGRES_PASSWORD || 'letzgo123',
        schema: process.env.DB_SCHEMA || 'public'
    },
    mongodb: {
        host: process.env.MONGODB_HOST || 'mongodb',
        port: process.env.MONGODB_PORT || 27017,
        database: process.env.MONGODB_DATABASE || 'letzgo',
        username: process.env.MONGODB_USERNAME || 'letzgo',
        password: process.env.MONGODB_PASSWORD || 'letzgo123'
    }
};

// Service-specific table requirements
const serviceSchemas = {
    'auth-service': {
        postgresql: ['users'],
        mongodb: []
    },
    'user-service': {
        postgresql: ['users', 'groups', 'group_memberships', 'invitations', 'stories', 'story_views'],
        mongodb: []
    },
    'event-service': {
        postgresql: ['users', 'events', 'event_participants', 'event_updates'],
        mongodb: []
    },
    'chat-service': {
        postgresql: ['users', 'chat_rooms', 'chat_participants', 'chat_messages', 'file_uploads'],
        mongodb: ['chat_rooms', 'chat_participants', 'chat_messages']
    },
    'splitz-service': {
        postgresql: ['users', 'groups', 'expenses', 'expense_splits', 'expense_categories'],
        mongodb: ['expenses', 'expense_splits', 'expense_categories']
    },
    'shared-service': {
        postgresql: ['users', 'notifications', 'push_tokens', 'file_uploads'],
        mongodb: []
    }
};

class SchemaValidator {
    constructor(serviceName, databaseType) {
        this.serviceName = serviceName;
        this.databaseType = databaseType;
        this.requiredTables = serviceSchemas[serviceName]?.[databaseType] || [];
    }

    async validateAndCreate() {
        console.log(`🔍 [${this.serviceName}] Validating ${this.databaseType} schema...`);
        
        if (this.requiredTables.length === 0) {
            console.log(`ℹ️  [${this.serviceName}] No ${this.databaseType} tables required`);
            return true;
        }

        try {
            if (this.databaseType === 'postgresql') {
                return await this.validatePostgreSQL();
            } else if (this.databaseType === 'mongodb') {
                return await this.validateMongoDB();
            }
        } catch (error) {
            console.error(`❌ [${this.serviceName}] Schema validation failed:`, error.message);
            return false;
        }
    }

    async validatePostgreSQL() {
        const pool = new Pool(config.postgresql);
        let client;

        try {
            client = await pool.connect();
            console.log(`✅ [${this.serviceName}] Connected to PostgreSQL`);

            // Check if required tables exist
            const missingTables = [];
            for (const tableName of this.requiredTables) {
                const result = await client.query(`
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables 
                        WHERE table_schema = $1 AND table_name = $2
                    );
                `, [config.postgresql.schema, tableName]);

                if (!result.rows[0].exists) {
                    missingTables.push(tableName);
                }
            }

            if (missingTables.length > 0) {
                console.log(`⚠️  [${this.serviceName}] Missing tables: ${missingTables.join(', ')}`);
                console.log(`🔧 [${this.serviceName}] Running database initialization...`);
                
                // Run initialization script
                const initScript = await fs.readFile(
                    path.join(__dirname, 'init-postgres.sql'), 
                    'utf8'
                );
                await client.query(initScript);
                console.log(`✅ [${this.serviceName}] Database initialization completed`);
            } else {
                console.log(`✅ [${this.serviceName}] All required tables exist`);
            }

            // Verify tables after initialization
            const finalCheck = [];
            for (const tableName of this.requiredTables) {
                const result = await client.query(`
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables 
                        WHERE table_schema = $1 AND table_name = $2
                    );
                `, [config.postgresql.schema, tableName]);

                if (result.rows[0].exists) {
                    finalCheck.push(tableName);
                }
            }

            console.log(`📊 [${this.serviceName}] Verified tables: ${finalCheck.join(', ')}`);
            return finalCheck.length === this.requiredTables.length;

        } finally {
            if (client) client.release();
            await pool.end();
        }
    }

    async validateMongoDB() {
        const uri = `mongodb://${config.mongodb.username}:${config.mongodb.password}@${config.mongodb.host}:${config.mongodb.port}/${config.mongodb.database}`;
        const client = new MongoClient(uri);

        try {
            await client.connect();
            console.log(`✅ [${this.serviceName}] Connected to MongoDB`);

            const db = client.db(config.mongodb.database);
            const existingCollections = await db.listCollections().toArray();
            const existingNames = existingCollections.map(c => c.name);

            const missingCollections = this.requiredTables.filter(
                collection => !existingNames.includes(collection)
            );

            if (missingCollections.length > 0) {
                console.log(`⚠️  [${this.serviceName}] Missing collections: ${missingCollections.join(', ')}`);
                console.log(`🔧 [${this.serviceName}] Running database initialization...`);
                
                // Run initialization script
                const initScript = await fs.readFile(
                    path.join(__dirname, 'init-mongodb.js'), 
                    'utf8'
                );
                
                // Execute MongoDB script (simplified version)
                for (const collectionName of missingCollections) {
                    await db.createCollection(collectionName);
                    console.log(`✅ [${this.serviceName}] Created collection: ${collectionName}`);
                }
            } else {
                console.log(`✅ [${this.serviceName}] All required collections exist`);
            }

            // Verify collections after initialization
            const finalCollections = await db.listCollections().toArray();
            const finalNames = finalCollections.map(c => c.name);
            const verifiedCollections = this.requiredTables.filter(
                collection => finalNames.includes(collection)
            );

            console.log(`📊 [${this.serviceName}] Verified collections: ${verifiedCollections.join(', ')}`);
            return verifiedCollections.length === this.requiredTables.length;

        } finally {
            await client.close();
        }
    }
}

// Main execution
async function main() {
    const serviceName = process.argv[2];
    const databaseType = process.argv[3];

    if (!serviceName || !databaseType) {
        console.error('❌ Usage: node schema-validator.js <service-name> <database-type>');
        console.error('   Examples:');
        console.error('     node schema-validator.js auth-service postgresql');
        console.error('     node schema-validator.js chat-service mongodb');
        process.exit(1);
    }

    if (!serviceSchemas[serviceName]) {
        console.error(`❌ Unknown service: ${serviceName}`);
        console.error(`   Available services: ${Object.keys(serviceSchemas).join(', ')}`);
        process.exit(1);
    }

    if (!['postgresql', 'mongodb'].includes(databaseType)) {
        console.error(`❌ Unknown database type: ${databaseType}`);
        console.error('   Available types: postgresql, mongodb');
        process.exit(1);
    }

    const validator = new SchemaValidator(serviceName, databaseType);
    const success = await validator.validateAndCreate();

    if (success) {
        console.log(`🎉 [${serviceName}] Schema validation completed successfully`);
        process.exit(0);
    } else {
        console.error(`💥 [${serviceName}] Schema validation failed`);
        process.exit(1);
    }
}

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('\n🛑 Schema validation interrupted');
    process.exit(1);
});

process.on('SIGTERM', () => {
    console.log('\n🛑 Schema validation terminated');
    process.exit(1);
});

if (require.main === module) {
    main().catch(error => {
        console.error('💥 Schema validation error:', error);
        process.exit(1);
    });
}

module.exports = { SchemaValidator };

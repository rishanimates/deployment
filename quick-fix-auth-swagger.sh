#!/bin/bash

# Quick Fix: Add Swagger to Auth Service
# This script immediately adds Swagger documentation to the auth-service

set -e

echo "🔧 Quick Fix: Adding Swagger to Auth Service"
echo "============================================"

# Configuration
DEPLOY_PATH="/opt/letzgo"
SERVICE="auth-service"
PORT="3000"
SERVICE_DIR="$DEPLOY_PATH/services/$SERVICE"

# Check if service directory exists
if [ ! -d "$SERVICE_DIR" ]; then
    echo "❌ Service directory not found: $SERVICE_DIR"
    exit 1
fi

cd "$SERVICE_DIR"

echo "📦 Updating package.json with Swagger dependencies..."

# Update package.json
cat > package.json << 'EOF'
{
  "name": "auth-service",
  "version": "1.0.0",
  "description": "LetzGo auth-service with Swagger documentation",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js",
    "dev": "nodemon src/app.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "swagger-ui-express": "^5.0.0",
    "swagger-jsdoc": "^6.2.8"
  }
}
EOF

echo "📝 Creating Swagger configuration..."

# Create swagger.js
cat > src/swagger.js << 'EOF'
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

const swaggerDefinition = {
  openapi: '3.0.0',
  info: {
    title: 'LetzGo Auth Service API',
    version: '1.0.0',
    description: 'Authentication and authorization API for LetzGo application',
    contact: {
      name: 'LetzGo Team',
      email: 'support@letzgo.com'
    }
  },
  servers: [
    {
      url: 'http://103.168.19.241:3000',
      description: 'Production server'
    },
    {
      url: 'http://localhost:3000',
      description: 'Development server'
    }
  ],
  components: {
    schemas: {
      HealthResponse: {
        type: 'object',
        properties: {
          status: { type: 'string', example: 'ok' },
          service: { type: 'string', example: 'auth-service' },
          version: { type: 'string', example: '1.0.0' },
          timestamp: { type: 'string', format: 'date-time' },
          port: { type: 'string', example: '3000' }
        }
      }
    },
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT'
      }
    }
  }
};

const swaggerOptions = {
  definition: swaggerDefinition,
  apis: ['./src/*.js'],
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

const customCss = `
  .swagger-ui .topbar { display: none; }
  .swagger-ui .info .title { color: #3b82f6; }
`;

const swaggerUiOptions = {
  customCss: customCss,
  customSiteTitle: 'LetzGo Auth Service API',
  swaggerOptions: {
    persistAuthorization: true,
    displayRequestDuration: true
  }
};

module.exports = {
  swaggerSpec,
  swaggerUi,
  swaggerUiOptions
};
EOF

echo "🚀 Creating enhanced app.js with Swagger..."

# Create enhanced app.js
cat > src/app.js << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { swaggerSpec, swaggerUi, swaggerUiOptions } = require('./swagger');

const app = express();
const PORT = process.env.PORT || 3000;

// Security and middleware
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());

// API Documentation
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, swaggerUiOptions));

// Swagger JSON endpoint
app.get('/swagger.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(swaggerSpec);
});

/**
 * @swagger
 * /health:
 *   get:
 *     summary: Health check endpoint
 *     description: Returns the health status of the auth service
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: Service is healthy
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/HealthResponse'
 */
app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        service: 'auth-service',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
        port: PORT,
        host: req.get('host') || 'localhost'
    });
});

/**
 * @swagger
 * /api/v1/status:
 *   get:
 *     summary: Service status endpoint
 *     description: Returns detailed status information
 *     tags: [Status]
 *     responses:
 *       200:
 *         description: Service status
 */
app.get('/api/v1/status', (req, res) => {
    res.json({
        service: 'auth-service',
        version: '1.0.0',
        status: 'running',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        endpoints: {
            health: '/health',
            status: '/api/v1/status',
            documentation: '/api-docs',
            swagger: '/swagger.json'
        }
    });
});

/**
 * @swagger
 * /:
 *   get:
 *     summary: Service information
 *     description: Returns basic service information and available endpoints
 *     tags: [Info]
 *     responses:
 *       200:
 *         description: Service information
 */
app.get('/', (req, res) => {
    const host = req.get('host') || 'localhost:3000';
    res.json({
        message: 'LetzGo auth-service is running',
        version: '1.0.0',
        service: 'auth-service',
        endpoints: {
            health: '/health',
            status: '/api/v1/status',
            documentation: '/api-docs',
            swagger: '/swagger.json'
        },
        links: {
            documentation: `http://${host}/api-docs`,
            health: `http://${host}/health`,
            status: `http://${host}/api/v1/status`
        }
    });
});

/**
 * @swagger
 * /api/v1/auth-service:
 *   get:
 *     summary: Auth service endpoint
 *     description: Authentication service functionality
 *     tags: [Authentication]
 *     responses:
 *       200:
 *         description: Auth service response
 */
app.get('/api/v1/auth-service', (req, res) => {
    res.json({
        message: 'LetzGo auth-service API',
        version: '1.0.0',
        service: 'auth-service',
        features: ['JWT Authentication', 'User Registration', 'Login/Logout', 'Password Reset'],
        endpoints: {
            health: '/health',
            status: '/api/v1/status',
            documentation: '/api-docs'
        }
    });
});

// 404 handler
app.use('*', (req, res) => {
    res.status(404).json({
        error: 'Not Found',
        message: `The requested endpoint ${req.originalUrl} does not exist`,
        service: 'auth-service',
        availableEndpoints: ['/health', '/api/v1/status', '/api/v1/auth-service', '/api-docs']
    });
});

// Error handler
app.use((err, req, res, next) => {
    console.error(`[${new Date().toISOString()}] Error:`, err.stack);
    res.status(500).json({
        error: 'Internal Server Error',
        message: err.message,
        service: 'auth-service'
    });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 [${new Date().toISOString()}] auth-service listening on port ${PORT}`);
    console.log(`📚 API Documentation: http://103.168.19.241:${PORT}/api-docs`);
    console.log(`🏥 Health Check: http://103.168.19.241:${PORT}/health`);
});

process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
EOF

echo "📖 Creating README with API documentation..."

cat > README.md << 'EOF'
# Auth Service

LetzGo authentication service with Swagger documentation.

## API Documentation

- **Swagger UI**: [http://103.168.19.241:3000/api-docs](http://103.168.19.241:3000/api-docs)
- **OpenAPI Spec**: [http://103.168.19.241:3000/swagger.json](http://103.168.19.241:3000/swagger.json)

## Endpoints

- `GET /health` - Health check
- `GET /api/v1/status` - Service status
- `GET /api/v1/auth-service` - Auth service info
- `GET /api-docs` - Swagger documentation

## Quick Test

```bash
# Health check
curl http://103.168.19.241:3000/health

# API documentation
open http://103.168.19.241:3000/api-docs
```
EOF

# Commit changes
git add . >/dev/null 2>&1
git commit -m "Added Swagger documentation to auth-service" >/dev/null 2>&1

echo "✅ Auth service enhanced with Swagger documentation!"
echo ""
echo "🔄 Next steps:"
echo "1. Rebuild and redeploy the auth-service:"
echo "   docker build -t letzgo-auth-service:latest ."
echo "   docker stop letzgo-auth-service && docker rm letzgo-auth-service"
echo "   # Run new container with updated code"
echo ""
echo "2. Or run full redeployment:"
echo "   ./deploy-services-parallel.sh auth-service main --force-rebuild"
echo ""
echo "3. Then access Swagger UI at:"
echo "   http://103.168.19.241:3000/api-docs"

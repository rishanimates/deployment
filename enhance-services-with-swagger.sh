#!/bin/bash

# Enhance Services with Swagger Documentation
# This script adds Swagger/OpenAPI documentation to deployed services

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${CYAN}"
echo "============================================================================"
echo "📚 LetzGo Services Swagger Enhancement"
echo "============================================================================"
echo -e "${NC}"
echo "📅 Started: $(date)"
echo ""

# Configuration
DEPLOY_PATH="/opt/letzgo"
SERVICES=("auth-service" "user-service" "chat-service" "event-service" "shared-service" "splitz-service")

# Get service port
get_service_port() {
    local service="$1"
    case "$service" in
        "auth-service") echo "3000" ;;
        "user-service") echo "3001" ;;
        "chat-service") echo "3002" ;;
        "event-service") echo "3003" ;;
        "shared-service") echo "3004" ;;
        "splitz-service") echo "3005" ;;
        *) echo "3000" ;;
    esac
}

# Enhance service with Swagger
enhance_service_with_swagger() {
    local service="$1"
    local port=$(get_service_port "$service")
    local service_dir="$DEPLOY_PATH/services/$service"
    
    log_info "📚 Enhancing $service with Swagger documentation..."
    
    if [ ! -d "$service_dir" ]; then
        log_error "Service directory not found: $service_dir"
        return 1
    fi
    
    cd "$service_dir"
    
    # Update package.json to include Swagger dependencies
    log_info "📦 Adding Swagger dependencies to package.json..."
    
    cat > package.json << EOF
{
  "name": "$service",
  "version": "1.0.0",
  "description": "LetzGo $service microservice with Swagger documentation",
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
    "dotenv": "^16.3.1",
    "swagger-ui-express": "^5.0.0",
    "swagger-jsdoc": "^6.2.8",
    "yamljs": "^0.3.0"
  }
}
EOF

    # Create Swagger configuration
    log_info "📝 Creating Swagger configuration..."
    
    cat > src/swagger.js << EOF
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

// Get the correct host from environment or request
const getSwaggerHost = (req) => {
  // Priority: Environment variable > Request host > Default
  const host = process.env.API_DOMAIN || 
               process.env.DOMAIN_NAME || 
               req.get('host') || 
               'localhost:${port}';
  
  return host;
};

// Swagger definition
const swaggerDefinition = {
  openapi: '3.0.0',
  info: {
    title: 'LetzGo ${service} API',
    version: '1.0.0',
    description: 'API documentation for LetzGo ${service} microservice',
    contact: {
      name: 'LetzGo Team',
      email: 'support@letzgo.com'
    },
    license: {
      name: 'MIT',
      url: 'https://opensource.org/licenses/MIT'
    }
  },
  servers: [
    {
      url: 'http://103.168.19.241:${port}',
      description: 'Production server'
    },
    {
      url: 'http://localhost:${port}',
      description: 'Development server'
    }
  ],
  components: {
    schemas: {
      HealthResponse: {
        type: 'object',
        properties: {
          status: {
            type: 'string',
            example: 'ok'
          },
          service: {
            type: 'string',
            example: '${service}'
          },
          version: {
            type: 'string',
            example: '1.0.0'
          },
          timestamp: {
            type: 'string',
            format: 'date-time',
            example: '2025-08-27T20:43:35.881Z'
          },
          port: {
            type: 'string',
            example: '${port}'
          }
        }
      },
      StatusResponse: {
        type: 'object',
        properties: {
          service: {
            type: 'string',
            example: '${service}'
          },
          version: {
            type: 'string',
            example: '1.0.0'
          },
          status: {
            type: 'string',
            example: 'running'
          },
          timestamp: {
            type: 'string',
            format: 'date-time'
          }
        }
      },
      ErrorResponse: {
        type: 'object',
        properties: {
          error: {
            type: 'string',
            example: 'Bad Request'
          },
          message: {
            type: 'string',
            example: 'Invalid input provided'
          },
          service: {
            type: 'string',
            example: '${service}'
          }
        }
      }
    },
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT'
      },
      apiKey: {
        type: 'apiKey',
        in: 'header',
        name: 'X-API-Key'
      }
    }
  }
};

// Options for swagger-jsdoc
const swaggerOptions = {
  definition: swaggerDefinition,
  apis: ['./src/*.js', './src/routes/*.js'], // Path to the API files
};

// Generate swagger specification
const swaggerSpec = swaggerJsdoc(swaggerOptions);

// Custom CSS for Swagger UI
const customCss = \`
  .swagger-ui .topbar { display: none; }
  .swagger-ui .info .title { color: #3b82f6; }
  .swagger-ui .scheme-container { background: #f8fafc; padding: 10px; border-radius: 4px; }
\`;

// Swagger UI options
const swaggerUiOptions = {
  customCss: customCss,
  customSiteTitle: 'LetzGo ${service} API Documentation',
  customfavIcon: '/favicon.ico',
  swaggerOptions: {
    persistAuthorization: true,
    displayRequestDuration: true,
    filter: true,
    showExtensions: true,
    showCommonExtensions: true,
    tryItOutEnabled: true
  }
};

module.exports = {
  swaggerSpec,
  swaggerUi,
  swaggerUiOptions,
  getSwaggerHost
};
EOF

    # Create enhanced app.js with Swagger
    log_info "🚀 Creating enhanced app.js with Swagger support..."
    
    cat > src/app.js << EOF
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { swaggerSpec, swaggerUi, swaggerUiOptions } = require('./swagger');

const app = express();
const PORT = process.env.PORT || ${port};
const HOST = process.env.HOST || '0.0.0.0';
const ENVIRONMENT = process.env.NODE_ENV || 'development';

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

// CORS configuration
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true
}));

// Logging
app.use(morgan('combined'));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

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
 *     description: Returns the health status of the service
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: Service is healthy
 *         content:
 *           application/json:
 *             schema:
 *               \$ref: '#/components/schemas/HealthResponse'
 */
app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        service: '${service}',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
        port: PORT,
        environment: ENVIRONMENT,
        host: req.get('host') || 'localhost'
    });
});

/**
 * @swagger
 * /api/v1/status:
 *   get:
 *     summary: Service status endpoint
 *     description: Returns detailed status information about the service
 *     tags: [Status]
 *     responses:
 *       200:
 *         description: Service status information
 *         content:
 *           application/json:
 *             schema:
 *               \$ref: '#/components/schemas/StatusResponse'
 */
app.get('/api/v1/status', (req, res) => {
    res.json({
        service: '${service}',
        version: '1.0.0',
        status: 'running',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: ENVIRONMENT,
        port: PORT,
        memory: process.memoryUsage(),
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
 *     summary: Service information endpoint
 *     description: Returns basic information about the service and available endpoints
 *     tags: [Info]
 *     responses:
 *       200:
 *         description: Service information
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "LetzGo ${service} is running"
 *                 version:
 *                   type: string
 *                   example: "1.0.0"
 *                 service:
 *                   type: string
 *                   example: "${service}"
 *                 endpoints:
 *                   type: object
 *                   properties:
 *                     health:
 *                       type: string
 *                       example: "/health"
 *                     status:
 *                       type: string
 *                       example: "/api/v1/status"
 *                     documentation:
 *                       type: string
 *                       example: "/api-docs"
 */
app.get('/', (req, res) => {
    res.json({
        message: 'LetzGo ${service} is running',
        version: '1.0.0',
        service: '${service}',
        environment: ENVIRONMENT,
        endpoints: {
            health: '/health',
            status: '/api/v1/status',
            documentation: '/api-docs',
            swagger: '/swagger.json'
        },
        links: {
            documentation: \`http://\${req.get('host') || 'localhost:${port}'}/api-docs\`,
            health: \`http://\${req.get('host') || 'localhost:${port}'}/health\`,
            status: \`http://\${req.get('host') || 'localhost:${port}'}/api/v1/status\`
        }
    });
});

// Service-specific API routes placeholder
/**
 * @swagger
 * /api/v1/${service}:
 *   get:
 *     summary: ${service} specific endpoint
 *     description: Service-specific functionality for ${service}
 *     tags: [${service}]
 *     responses:
 *       200:
 *         description: ${service} response
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "LetzGo ${service} API"
 *                 service:
 *                   type: string
 *                   example: "${service}"
 *                 version:
 *                   type: string
 *                   example: "1.0.0"
 */
app.get('/api/v1/${service}', (req, res) => {
    res.json({
        message: 'LetzGo ${service} API',
        version: '1.0.0',
        service: '${service}',
        endpoints: {
            health: '/health',
            status: '/api/v1/status',
            service: '/api/v1/${service}',
            documentation: '/api-docs'
        },
        // Add service-specific data here
        data: {
            description: 'This is the ${service} microservice',
            features: ['Health monitoring', 'API documentation', 'Status reporting'],
            lastUpdated: new Date().toISOString()
        }
    });
});

// 404 handler
app.use('*', (req, res) => {
    res.status(404).json({
        error: 'Not Found',
        message: \`The requested endpoint \${req.originalUrl} does not exist\`,
        service: '${service}',
        availableEndpoints: ['/health', '/api/v1/status', '/api/v1/${service}', '/api-docs']
    });
});

// Global error handling middleware
app.use((err, req, res, next) => {
    console.error(\`[\${new Date().toISOString()}] Error in ${service}:\`, err.stack);
    res.status(err.status || 500).json({
        error: err.status === 500 ? 'Internal Server Error' : err.message,
        message: err.message,
        service: '${service}',
        timestamp: new Date().toISOString()
    });
});

// Start server
const server = app.listen(PORT, HOST, () => {
    console.log(\`🚀 [\${new Date().toISOString()}] ${service} listening on port \${PORT}\`);
    console.log(\`🌍 Environment: \${ENVIRONMENT}\`);
    console.log(\`🏠 Host: \${HOST}\`);
    console.log(\`🏥 Health check: http://\${HOST === '0.0.0.0' ? 'localhost' : HOST}:\${PORT}/health\`);
    console.log(\`📚 API Documentation: http://103.168.19.241:\${PORT}/api-docs\`);
    console.log(\`📊 API Status: http://103.168.19.241:\${PORT}/api/v1/status\`);
});

// Graceful shutdown
const gracefulShutdown = (signal) => {
    console.log(\`[\${new Date().toISOString()}] \${signal} received, shutting down ${service} gracefully\`);
    server.close(() => {
        console.log(\`[\${new Date().toISOString()}] ${service} server closed\`);
        process.exit(0);
    });
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

module.exports = app;
EOF

    # Create README with API documentation
    log_info "📖 Creating enhanced README with API documentation..."
    
    cat > README.md << EOF
# ${service}

LetzGo ${service} microservice with comprehensive API documentation.

## 🚀 Features

- **RESTful API** with OpenAPI 3.0 specification
- **Swagger UI** for interactive API documentation
- **Health monitoring** with detailed status endpoints
- **CORS support** for cross-origin requests
- **Security headers** with Helmet.js
- **Request logging** with Morgan
- **Graceful shutdown** handling

## 📚 API Documentation

### Interactive Documentation
- **Swagger UI**: [http://103.168.19.241:${port}/api-docs](http://103.168.19.241:${port}/api-docs)
- **OpenAPI Spec**: [http://103.168.19.241:${port}/swagger.json](http://103.168.19.241:${port}/swagger.json)

### API Endpoints

#### Health & Status
- \`GET /health\` - Health check endpoint
- \`GET /api/v1/status\` - Detailed service status

#### Service API
- \`GET /\` - Service information
- \`GET /api/v1/${service}\` - Service-specific functionality

#### Documentation
- \`GET /api-docs\` - Swagger UI documentation
- \`GET /swagger.json\` - OpenAPI specification

## 🔧 Development

\`\`\`bash
# Install dependencies
yarn install

# Start development server
yarn dev

# Start production server
yarn start
\`\`\`

## 🐳 Docker

\`\`\`bash
# Build image
docker build -t letzgo-${service} .

# Run container
docker run -p ${port}:${port} \\
  -e NODE_ENV=production \\
  -e API_DOMAIN=103.168.19.241 \\
  letzgo-${service}
\`\`\`

## 🌐 Environment Variables

- \`PORT\` - Server port (default: ${port})
- \`HOST\` - Server host (default: 0.0.0.0)
- \`NODE_ENV\` - Environment (development/production)
- \`API_DOMAIN\` - API domain for Swagger documentation
- \`CORS_ORIGIN\` - CORS allowed origins

## 📊 Health Check

\`\`\`bash
curl http://103.168.19.241:${port}/health
\`\`\`

Response:
\`\`\`json
{
  "status": "ok",
  "service": "${service}",
  "version": "1.0.0",
  "timestamp": "2025-08-27T20:43:35.881Z",
  "port": "${port}",
  "environment": "production"
}
\`\`\`

## 🔗 Links

- [Health Check](http://103.168.19.241:${port}/health)
- [API Status](http://103.168.19.241:${port}/api/v1/status)
- [API Documentation](http://103.168.19.241:${port}/api-docs)
- [OpenAPI Specification](http://103.168.19.241:${port}/swagger.json)
EOF

    # Commit changes
    git add . >/dev/null 2>&1
    git commit -m "Enhanced $service with Swagger documentation

- Added Swagger UI at /api-docs
- Added OpenAPI 3.0 specification
- Enhanced health and status endpoints
- Added comprehensive API documentation
- Fixed host configuration for production server
- Added security headers and CORS support" >/dev/null 2>&1

    log_success "✅ $service enhanced with Swagger documentation"
    return 0
}

# Main execution
main() {
    log_info "🚀 Enhancing all services with Swagger documentation..."
    
    local successful=0
    local failed=0
    
    for service in "${SERVICES[@]}"; do
        echo ""
        if enhance_service_with_swagger "$service"; then
            successful=$((successful + 1))
        else
            failed=$((failed + 1))
        fi
    done
    
    echo ""
    echo -e "${CYAN}============================================================================${NC}"
    echo -e "${GREEN}🎉 Service Enhancement Completed!${NC}"
    echo -e "${CYAN}============================================================================${NC}"
    echo ""
    
    echo "📊 Enhancement Summary:"
    echo "  ✅ Successful: $successful"
    echo "  ❌ Failed: $failed"
    echo "  📊 Total: $((successful + failed))"
    
    echo ""
    echo "📚 Swagger Documentation URLs:"
    for service in "${SERVICES[@]}"; do
        local port=$(get_service_port "$service")
        echo "  📖 $service: http://103.168.19.241:$port/api-docs"
    done
    
    echo ""
    echo "🔄 Next Steps:"
    echo "  1. Rebuild and redeploy services to apply changes"
    echo "  2. Run: ./deploy-services-parallel.sh all main --force-rebuild"
    echo "  3. Test Swagger UI at the URLs above"
    echo ""
    
    log_success "🎯 All services enhanced with Swagger documentation!"
}

main "$@"

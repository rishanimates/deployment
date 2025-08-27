# LetzGo Deployment

Clean deployment infrastructure for LetzGo microservices platform.

## 🚀 GitHub Actions Workflows

### 1. Deploy Infrastructure
- **File**: `.github/workflows/deploy-infrastructure.yml`
- **Purpose**: Deploy database infrastructure (PostgreSQL, MongoDB, Redis, RabbitMQ)

### 2. Deploy Services (Multiple Repositories)
- **File**: `.github/workflows/deploy-services-multi-repo.yml`
- **Purpose**: Deploy microservices from individual GitHub repositories
- **Features**: Parallel deployment, repository selection, branch selection

## 📋 Available Services

| Service | Port | Swagger Documentation |
|---------|------|----------------------|
| **Auth Service** | 3000 | http://103.168.19.241:3000/api-docs |
| **User Service** | 3001 | http://103.168.19.241:3001/api-docs |
| **Chat Service** | 3002 | http://103.168.19.241:3002/api-docs |
| **Event Service** | 3003 | http://103.168.19.241:3003/api-docs |
| **Shared Service** | 3004 | http://103.168.19.241:3004/api-docs |
| **Splitz Service** | 3005 | http://103.168.19.241:3005/api-docs |

## ✅ Clean Solution

- ✅ No patch scripts - Swagger fixed directly in service repositories
- ✅ Only 2 workflows in deployment directory
- ✅ Each service deployed from its own repository
- ✅ Parallel deployment for faster execution
- ✅ Production server URLs configured properly


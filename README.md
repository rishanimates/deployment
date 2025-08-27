# 🏗️ LetzGo Deployment System

A clean, reliable deployment system for the LetzGo application with separate infrastructure and services deployment.

## 📋 Overview

This deployment system consists of two main scripts:

1. **`deploy-infrastructure.sh`** - Deploys all databases and messaging services with schemas
2. **`deploy-services.sh`** - Deploys application microservices with proper networking

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose installed on VPS
- SSH access to VPS (103.168.19.241:7576)
- Sufficient disk space and memory

### 1. Deploy Infrastructure First
```bash
# Deploy all databases and create schemas
./deploy-infrastructure.sh

# Or force rebuild (removes all existing data)
./deploy-infrastructure.sh --force-rebuild
```

### 2. Deploy Services
```bash
# Deploy all services
./deploy-services.sh

# Deploy specific services
./deploy-services.sh auth-service,user-service

# Force rebuild Docker images
./deploy-services.sh --force-rebuild
```

## 📊 Infrastructure Components

### Databases & Services
- **PostgreSQL** (TimescaleDB) - Port 5432
  - Main application database
  - Automatic schema initialization
  - Time-series capabilities
- **MongoDB** - Port 27017
  - Chat and real-time data
  - Document validation rules
- **Redis** - Port 6379
  - Caching and sessions
  - Password protected
- **RabbitMQ** - Port 5672, Management 15672
  - Message queuing
  - Management UI available

### Network
- **Docker Network**: `letzgo-network`
- **Container Naming**: `letzgo-{service-name}`

## 🎯 Application Services

| Service | Port | Description |
|---------|------|-------------|
| auth-service | 3000 | Authentication & authorization |
| user-service | 3001 | User management |
| chat-service | 3002 | Real-time messaging |
| event-service | 3003 | Event management |
| shared-service | 3004 | Shared utilities |
| splitz-service | 3005 | Expense splitting |

## 🔧 Configuration

### Environment Variables
All services automatically receive:
- Database connection strings
- Service discovery URLs
- Security tokens
- Domain configuration

### Generated Files
- `/opt/letzgo/.env` - Environment variables
- `/opt/letzgo/docker-compose.infrastructure.yml` - Infrastructure config
- `/opt/letzgo/database/init/` - Database schemas

## 📈 Database Schemas

### PostgreSQL Tables
- `users` - User accounts and profiles
- `groups` - User groups and communities  
- `group_memberships` - Group membership relationships
- `events` - Event management
- `event_participants` - Event participation
- `expenses` - Expense tracking
- `expense_splits` - Expense splitting
- `messages` - Chat messages (TimescaleDB)
- `notifications` - User notifications
- `file_uploads` - File management

### MongoDB Collections
- `chat_rooms` - Chat room management
- `chat_messages` - Real-time messages
- `expense_groups` - Expense group management
- `expenses` - Expense documents
- `settlements` - Payment settlements
- `user_presence` - Real-time user status
- `activity_feed` - User activity tracking

## 🔍 Health Monitoring

### Infrastructure Health
```bash
# Check all infrastructure services
docker ps | grep letzgo

# Test database connectivity
docker exec letzgo-postgres pg_isready -U postgres -d letzgo
docker exec letzgo-mongodb mongosh --eval "db.adminCommand('ping')"
docker exec letzgo-redis redis-cli --no-auth-warning -a <password> ping
```

### Service Health
```bash
# Check service health endpoints
curl http://localhost:3000/health  # auth-service
curl http://localhost:3001/health  # user-service
curl http://localhost:3002/health  # chat-service
# ... etc
```

## 🐳 GitHub Actions

### Infrastructure Deployment
**Workflow**: `Deploy Infrastructure`
- Triggers: Manual dispatch
- Options: Force rebuild
- Deploys: All databases and schemas

### Services Deployment  
**Workflow**: `Deploy Services`
- Triggers: Manual dispatch
- Options: Select services, force rebuild
- Deploys: Application microservices

## 🛠️ Troubleshooting

### Common Issues

1. **Port Conflicts**
   ```bash
   netstat -tlnp | grep :5432  # Check if port is in use
   sudo kill <PID>             # Kill conflicting process
   ```

2. **Docker Issues**
   ```bash
   sudo systemctl start docker
   sudo usermod -aG docker $USER
   ```

3. **Network Issues**
   ```bash
   docker network ls | grep letzgo
   docker network rm letzgo-network  # If stuck
   ```

4. **Database Connection Issues**
   ```bash
   # Check container logs
   docker logs letzgo-postgres
   docker logs letzgo-mongodb
   
   # Verify environment variables
   cat /opt/letzgo/.env
   ```

### Clean Restart
```bash
# Stop all services
docker stop $(docker ps -q --filter name=letzgo)

# Remove all containers
docker rm $(docker ps -aq --filter name=letzgo)

# Remove network
docker network rm letzgo-network

# Clean deployment directory
sudo rm -rf /opt/letzgo

# Restart deployment
./deploy-infrastructure.sh --force-rebuild
./deploy-services.sh --force-rebuild
```

## 📝 Logs

### Infrastructure Logs
```bash
docker logs letzgo-postgres
docker logs letzgo-mongodb  
docker logs letzgo-redis
docker logs letzgo-rabbitmq
```

### Service Logs
```bash
docker logs letzgo-auth-service
docker logs letzgo-user-service
# ... etc
```

### Application Logs
- **Location**: `/opt/letzgo/logs/`
- **Format**: JSON structured logs
- **Rotation**: Automatic with size limits

## 🔐 Security

### Passwords
- **Generated**: Cryptographically secure random passwords
- **Length**: 40-64 characters
- **Storage**: Environment file with 600 permissions

### Network Security
- **Internal**: Services communicate via Docker network
- **External**: Only necessary ports exposed
- **Authentication**: All services require API keys

## 📊 Resource Requirements

### Minimum Requirements
- **CPU**: 2 cores
- **RAM**: 4GB
- **Disk**: 20GB
- **Network**: Stable internet connection

### Recommended
- **CPU**: 4+ cores  
- **RAM**: 8GB+
- **Disk**: 50GB+ SSD
- **Network**: High-speed connection

## 🎉 Success Indicators

### Infrastructure Deployment Success
```
✅ Step 1/7: System check passed
✅ Step 2/7: Directories setup completed  
✅ Step 3/7: Environment configuration created
✅ Step 4/7: Docker Compose configuration created
✅ Step 5/7: Existing containers cleanup completed
✅ Step 6/7: Infrastructure deployment completed
✅ Step 7/7: Health check completed

🎉 LetzGo Infrastructure Deployment Completed Successfully!
```

### Services Deployment Success
```
✅ auth-service deployment completed
✅ user-service deployment completed
✅ chat-service deployment completed
✅ event-service deployment completed
✅ shared-service deployment completed
✅ splitz-service deployment completed

🎉 LetzGo Services Deployment Completed!
```

## 📞 Support

If you encounter issues:

1. **Check logs** for error messages
2. **Verify prerequisites** are met
3. **Try clean restart** procedure
4. **Check GitHub Actions** logs for deployment issues
5. **Review troubleshooting** section above

---

**🎯 This deployment system provides a clean, reliable foundation for the LetzGo application with proper separation of concerns between infrastructure and application services.**
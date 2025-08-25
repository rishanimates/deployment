# LetzGo Production Deployment Guide

This directory contains all the necessary files and scripts for deploying the LetzGo microservices platform to production using GitHub Actions and Docker.

## 🏗️ Architecture Overview

The LetzGo platform consists of 6 microservices:
- **auth-service** (Port 3000) - Authentication and authorization
- **user-service** (Port 3001) - User management and profiles
- **chat-service** (Port 3002) - Real-time messaging
- **event-service** (Port 3003) - Event management and ticketing
- **shared-service** (Port 3004) - Shared utilities (storage, payments, notifications)
- **splitz-service** (Port 3005) - Expense splitting and management

## 🚀 Quick Start

### 1. SSH Key Setup

First, set up SSH access to your VPS:

```bash
cd deployment
chmod +x setup-ssh.sh
./setup-ssh.sh
```

This script will:
- Generate SSH keys for GitHub Actions
- Install the public key on your VPS
- Set up the server environment
- Display the secrets you need to add to GitHub

### 2. GitHub Repository Secrets

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

```
VPS_HOST=103.168.19.241
VPS_PORT=7576
VPS_USER=root
VPS_SSH_KEY=<private_key_from_setup_script>
```

### 3. Environment Configuration

Copy the environment template and configure it:

```bash
cp env.template .env
# Edit .env with your actual values
```

**⚠️ Important**: Update all default passwords and secrets in the `.env` file!

### 4. Deploy

Push your code to the `main` branch to trigger automatic deployment:

```bash
git add .
git commit -m "Initial deployment setup"
git push origin main
```

## 📁 File Structure

```
deployment/
├── .github/workflows/           # GitHub Actions workflows
│   ├── ci.yml                  # Continuous Integration
│   ├── deploy.yml              # Production deployment
│   └── rollback.yml            # Rollback mechanism
├── nginx/                      # Nginx configuration
│   ├── nginx.conf              # Main Nginx config
│   └── conf.d/letzgo.conf     # API Gateway configuration
├── schemas/                    # Database schemas (auto-populated)
├── 00-init-dbs.sh             # Database initialization script
├── 02-create-hypertable.sql   # TimescaleDB hypertable setup
├── deploy.sh                  # Main deployment script
├── docker-compose.prod.yml    # Production Docker Compose
├── docker-compose.yml         # Development Docker Compose
├── env.template               # Environment variables template
├── install.sh                 # Local development setup
├── setup-ssh.sh              # SSH key setup script
└── README.md                  # This file
```

## 🔄 Deployment Workflows

### Continuous Integration (CI)
Triggered on: Pull requests and pushes to `develop`

- **Linting**: ESLint checks for all services
- **Building**: Docker image builds for each service
- **Testing**: Unit and integration tests
- **Security**: npm audit and Snyk scanning
- **Dependencies**: Check for outdated packages

### Continuous Deployment (CD)
Triggered on: Pushes to `main` branch

1. **Build Phase**:
   - Install dependencies
   - Run tests
   - Create deployment package
   - Upload artifacts

2. **Deploy Phase**:
   - Copy files to VPS
   - Stop current services
   - Deploy new version
   - Start services
   - Verify deployment

3. **Notification Phase**:
   - Send deployment status notifications

### Rollback
Manually triggered via GitHub Actions

- Creates pre-rollback backup
- Stops current services
- Restores from specified backup
- Starts services
- Verifies rollback success

## 🗄️ Database Setup

The platform uses a unified PostgreSQL database with separate schemas:
- `auth` - Authentication data
- `users` - User profiles and relationships
- `events` - Event and ticketing data
- `shared` - Shared service data
- `chat` - Chat messages (also uses MongoDB)
- `splitz` - Expense data (also uses MongoDB)

Additional databases:
- **MongoDB**: Chat messages and expense data
- **Redis**: Caching and sessions
- **RabbitMQ**: Message queuing

## 🔧 Service Configuration

Each service is configured via environment variables. Key configurations:

### Database Connections
```env
POSTGRES_URL=postgresql://user:pass@host:5432/letzgo_db
MONGO_URI=mongodb://user:pass@host:27017/database
REDIS_HOST=host
REDIS_PORT=6379
RABBITMQ_URL=amqp://user:pass@host:5672
```

### Service Authentication
```env
JWT_SECRET=your_jwt_secret_key
SERVICE_API_KEY=your_service_api_key
```

### External Services
```env
RAZORPAY_KEY_ID=your_razorpay_key
RAZORPAY_KEY_SECRET=your_razorpay_secret
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
```

## 🌐 API Gateway (Nginx)

The Nginx reverse proxy provides:
- **Load balancing** across service instances
- **Rate limiting** to prevent abuse
- **SSL termination** (when configured)
- **Static file serving** for uploads
- **Health checks** for monitoring

### API Endpoints
- `/api/auth/` → auth-service:3000
- `/api/users/` → user-service:3001
- `/api/chat/` → chat-service:3002
- `/api/events/` → event-service:3003
- `/api/shared/` → shared-service:3004
- `/api/splitz/` → splitz-service:3005

## 🔍 Monitoring and Logging

### Health Checks
All services expose `/health` endpoints for monitoring.

### Logs
Logs are stored in `/opt/letzgo/logs/`:
- `deployment.log` - Deployment logs
- `nginx/` - Nginx access and error logs
- Service-specific logs in each container

### Container Status
Check running containers:
```bash
docker ps
docker-compose -f /opt/letzgo/docker-compose.prod.yml ps
```

## 🛠️ Manual Operations

### Deploy Manually
```bash
ssh -p 7576 root@103.168.19.241
cd /opt/letzgo
./deploy.sh
```

### View Logs
```bash
# Deployment logs
tail -f /opt/letzgo/logs/deployment.log

# Service logs
docker-compose -f /opt/letzgo/docker-compose.prod.yml logs -f

# Specific service logs
docker logs letzgo-auth-service -f
```

### Restart Services
```bash
cd /opt/letzgo
docker-compose -f docker-compose.prod.yml restart
```

### Database Access
```bash
# PostgreSQL
docker exec -it letzgo-postgres psql -U postgres -d letzgo_db

# MongoDB
docker exec -it letzgo-mongodb mongosh

# Redis
docker exec -it letzgo-redis redis-cli
```

## 🔒 Security Considerations

1. **Change default passwords** in the environment file
2. **Use strong JWT secrets** (at least 32 characters)
3. **Configure SSL certificates** for HTTPS
4. **Regular security updates** for base images
5. **Monitor logs** for suspicious activity
6. **Backup databases** regularly

## 🚨 Troubleshooting

### Services Not Starting
1. Check logs: `docker-compose logs`
2. Verify environment variables
3. Check database connectivity
4. Ensure ports are not in use

### Database Connection Issues
1. Verify database credentials
2. Check network connectivity
3. Ensure databases are initialized
4. Check schema permissions

### Performance Issues
1. Monitor resource usage: `docker stats`
2. Check database query performance
3. Review Nginx access logs
4. Scale services if needed

### Rollback Issues
1. Check available backups: `ls /opt/letzgo/backups/`
2. Verify backup integrity
3. Use manual restoration if needed

## 📞 Support

For deployment issues:
1. Check GitHub Actions logs
2. Review deployment logs on VPS
3. Verify service health endpoints
4. Check container status and logs

## 🔄 Backup and Recovery

### Automated Backups
Backups are created automatically before each deployment in `/opt/letzgo/backups/`

### Manual Backup
```bash
cd /opt/letzgo
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
mkdir -p backups/manual_$TIMESTAMP
cp -r app backups/manual_$TIMESTAMP/
cp .env backups/manual_$TIMESTAMP/
```

### Database Backup
```bash
# PostgreSQL backup
docker exec letzgo-postgres pg_dump -U postgres letzgo_db > backup.sql

# MongoDB backup
docker exec letzgo-mongodb mongodump --out /backup
```

## 🚀 Scaling

To scale the platform:
1. **Horizontal scaling**: Add more VPS instances behind a load balancer
2. **Service scaling**: Use Docker Compose scale or Kubernetes
3. **Database scaling**: Implement read replicas and sharding
4. **CDN**: Use CloudFront or similar for static assets

---

## 📋 Checklist

Before going to production:

- [ ] SSH keys configured
- [ ] GitHub secrets added
- [ ] Environment file configured with real values
- [ ] SSL certificates obtained (optional)
- [ ] Monitoring setup
- [ ] Backup strategy implemented
- [ ] Team access configured
- [ ] Documentation updated

---

**🎉 Your LetzGo platform is now ready for production!**

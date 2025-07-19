# Sertantai Documentation App - Deployment Guide

This guide covers deploying the Sertantai documentation application to production environments.

## Prerequisites

- Elixir 1.15+ and Erlang/OTP 26+
- Node.js 18+ (for asset compilation)
- Production server with adequate resources
- Domain name and SSL certificate (recommended)

## Environment Variables

Configure the following environment variables in your production environment:

### Required Variables

```bash
# Phoenix Configuration
SECRET_KEY_BASE=your-secret-key-base-here
PHX_HOST=docs.sertantai.com
PORT=4000
PHX_SERVER=true

# Application Configuration
MAIN_APP_URL=https://sertantai.com
```

### Optional Variables

```bash
# Content Management
ENABLE_FILE_MONITORING=false          # Usually disabled in production
DISABLE_CONTENT_SYNC=false           # Set to true to disable sync
CONTENT_CACHE_TTL=3600               # Cache TTL in seconds (1 hour)
MAX_CONTENT_SIZE=10485760            # Max content size in bytes (10MB)

# DNS Clustering (for multi-node deployments)
DNS_CLUSTER_QUERY=your-cluster-query

# SSL Configuration (if using custom SSL)
SSL_KEY_PATH=/path/to/ssl/key
SSL_CERT_PATH=/path/to/ssl/cert
```

## Build and Release Process

### 1. Prepare the Release

```bash
# Set production environment
export MIX_ENV=prod

# Install dependencies
mix deps.get --only prod

# Compile application
mix compile

# Build and deploy assets
mix assets.deploy

# Create release
mix release
```

### 2. Alternative: Using Docker

Create a `Dockerfile`:

```dockerfile
FROM elixir:1.15-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git nodejs npm

# Set environment
ENV MIX_ENV=prod

# Create app directory
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Install and build assets
COPY assets/package.json assets/package-lock.json ./assets/
RUN cd assets && npm ci --production=false

COPY priv priv
COPY assets assets
RUN mix assets.deploy

# Copy source code
COPY config config
COPY lib lib
COPY rel rel

# Compile and create release
RUN mix compile
RUN mix release

# Create runtime image
FROM alpine:3.18 AS runtime

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs libstdc++

# Create app user
RUN adduser -D app
USER app

# Copy release
COPY --from=build --chown=app:app /app/_build/prod/rel/sertantai_docs ./

# Expose port
EXPOSE 4000

# Start the application
CMD ["./bin/sertantai_docs", "start"]
```

### 3. Build Docker Image

```bash
docker build -t sertantai-docs .
docker run -p 4000:4000 --env-file .env.prod sertantai-docs
```

## Deployment Options

### Option 1: Traditional VPS/Server Deployment

1. **Server Setup**
   ```bash
   # Update system
   sudo apt update && sudo apt upgrade -y
   
   # Install Elixir and Erlang
   sudo apt install elixir erlang-dev erlang-xmerl
   
   # Install Node.js (for asset compilation)
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt install nodejs
   ```

2. **Application Deployment**
   ```bash
   # Create application directory
   sudo mkdir -p /opt/sertantai-docs
   sudo chown $USER:$USER /opt/sertantai-docs
   cd /opt/sertantai-docs
   
   # Clone and build application
   git clone <repository-url> .
   mix deps.get --only prod
   mix assets.deploy
   mix release
   
   # Create systemd service
   sudo cp rel/sertantai_docs.service /etc/systemd/system/
   sudo systemctl enable sertantai-docs
   sudo systemctl start sertantai-docs
   ```

### Option 2: Docker Deployment

1. **Docker Compose Setup**
   
   Create `docker-compose.yml`:
   ```yaml
   version: '3.8'
   services:
     docs:
       build: .
       ports:
         - "4000:4000"
       environment:
         - SECRET_KEY_BASE=${SECRET_KEY_BASE}
         - PHX_HOST=${PHX_HOST}
         - PHX_SERVER=true
         - MAIN_APP_URL=${MAIN_APP_URL}
       volumes:
         - ./content:/app/priv/static/docs:ro
       restart: unless-stopped
   
     nginx:
       image: nginx:alpine
       ports:
         - "80:80"
         - "443:443"
       volumes:
         - ./nginx.conf:/etc/nginx/nginx.conf:ro
         - ./ssl:/etc/nginx/ssl:ro
       depends_on:
         - docs
       restart: unless-stopped
   ```

2. **Deploy with Docker Compose**
   ```bash
   docker-compose up -d
   ```

### Option 3: Platform Deployment (Fly.io, Render, etc.)

1. **Fly.io Deployment**
   ```bash
   # Install flyctl
   curl -L https://fly.io/install.sh | sh
   
   # Initialize Fly app
   fly launch
   
   # Set secrets
   fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
   fly secrets set PHX_HOST=your-app.fly.dev
   fly secrets set MAIN_APP_URL=https://sertantai.com
   
   # Deploy
   fly deploy
   ```

## Web Server Configuration

### Nginx Configuration

Create `/etc/nginx/sites-available/sertantai-docs`:

```nginx
upstream sertantai_docs {
    server 127.0.0.1:4000;
}

server {
    listen 80;
    server_name docs.sertantai.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name docs.sertantai.com;

    # SSL Configuration
    ssl_certificate /path/to/ssl/cert.pem;
    ssl_certificate_key /path/to/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;

    # Gzip Compression
    gzip on;
    gzip_types text/css application/javascript application/json application/font-woff application/font-tff image/gif image/png image/jpeg application/octet-stream;

    # Static Asset Caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
        access_log off;
    }

    # Proxy to Phoenix
    location / {
        proxy_pass http://sertantai_docs;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }

    # Health Check Endpoint
    location /health {
        access_log off;
        proxy_pass http://sertantai_docs;
    }
}
```

## Monitoring and Logging

### Application Logging

The application uses structured logging in production. Logs are sent to stdout and can be captured by your deployment platform or log aggregation service.

### Health Checks

The application provides a health check endpoint at `/health` that returns:
- HTTP 200 if the application is healthy
- Basic application status information

### Metrics and Monitoring

The application includes Phoenix LiveDashboard for monitoring in development. For production monitoring, consider:

1. **Application Performance Monitoring (APM)**
   - AppSignal
   - New Relic
   - DataDog

2. **Error Tracking**
   - Sentry
   - Bugsnag
   - Rollbar

3. **Infrastructure Monitoring**
   - Prometheus + Grafana
   - CloudWatch (AWS)
   - Platform-specific monitoring

## Content Management

### Content Updates

1. **File-based Updates**
   - Content files are stored in `priv/static/docs/`
   - Updates can be deployed via git or file sync
   - The Integration GenServer monitors for changes

2. **Content Synchronization**
   - Automatic sync can be enabled/disabled via `DISABLE_CONTENT_SYNC`
   - Manual sync available via dev API endpoints
   - Content is cached based on `CONTENT_CACHE_TTL`

### Content Structure

```
priv/static/docs/
├── index.md              # Homepage content
├── dev/                  # Developer documentation
│   ├── index.md
│   ├── setup.md
│   └── architecture.md
└── user/                 # User documentation
    ├── index.md
    ├── getting-started.md
    └── features.md
```

## Security Considerations

### Application Security

1. **Secret Management**
   - Never commit secrets to version control
   - Use environment variables for all secrets
   - Rotate secrets regularly

2. **Content Security**
   - Markdown content is processed safely by MDEx
   - HTML output is sanitized
   - Cross-site scripting (XSS) prevention

3. **Network Security**
   - Always use HTTPS in production
   - Configure proper firewall rules
   - Limit access to admin endpoints

### Deployment Security

1. **Server Hardening**
   - Keep system packages updated
   - Use minimal attack surface
   - Configure proper user permissions

2. **Container Security**
   - Use minimal base images
   - Run as non-root user
   - Scan images for vulnerabilities

## Troubleshooting

### Common Issues

1. **Assets Not Loading**
   ```bash
   # Rebuild and deploy assets
   mix assets.deploy
   ```

2. **Application Won't Start**
   ```bash
   # Check environment variables
   printenv | grep -E "(SECRET_KEY_BASE|PHX_HOST|PORT)"
   
   # Check application logs
   journalctl -u sertantai-docs -f
   ```

3. **Content Not Updating**
   ```bash
   # Check file permissions
   ls -la priv/static/docs/
   
   # Trigger manual sync (development)
   curl -X POST http://localhost:4000/dev-api/integration/sync
   ```

### Performance Optimization

1. **Asset Optimization**
   - Ensure assets are compressed and cached
   - Use CDN for static assets
   - Optimize images and fonts

2. **Application Optimization**
   - Adjust content cache TTL
   - Monitor memory usage
   - Scale horizontally if needed

## Backup and Recovery

### Content Backup

```bash
# Backup content directory
tar -czf content-backup-$(date +%Y%m%d).tar.gz priv/static/docs/

# Restore content
tar -xzf content-backup-YYYYMMDD.tar.gz
```

### Application Backup

```bash
# Create complete application backup
tar -czf app-backup-$(date +%Y%m%d).tar.gz --exclude=_build --exclude=deps .
```

## Scaling Considerations

### Horizontal Scaling

- The application is stateless except for content caching
- Multiple instances can be deployed behind a load balancer
- Shared content storage may be needed for multi-instance deployments

### Vertical Scaling

- Monitor CPU and memory usage
- Adjust Erlang VM settings as needed
- Consider content cache size vs. memory usage

## Support and Maintenance

### Regular Maintenance

1. **Security Updates**
   - Update Elixir and dependencies regularly
   - Monitor security advisories
   - Apply patches promptly

2. **Performance Monitoring**
   - Monitor response times
   - Check error rates
   - Review resource usage

3. **Content Management**
   - Regular content audits
   - Link validation
   - Performance optimization

### Getting Help

- Check application logs first
- Use development API endpoints for debugging
- Review this deployment guide
- Contact the development team for complex issues

---

For additional help or questions about deployment, please refer to the main Sertantai documentation or contact the development team.
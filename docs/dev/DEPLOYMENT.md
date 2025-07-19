# Deployment Guide - Sertantai Authentication & Sync System

## Production Deployment Checklist

### 1. Environment Configuration

#### Required Environment Variables:
```bash
# Database Configuration
DATABASE_URL=postgresql://user:password@host:port/database
SUPABASE_PASSWORD=your_supabase_password
SUPABASE_DATABASE=your_database_name

# Application Secrets
SECRET_KEY_BASE=your_secret_key_base_64_chars
TOKEN_SIGNING_SECRET=your_token_signing_secret_64_chars

# External API Configuration (if using)
AIRTABLE_API_KEY=your_airtable_api_key
NOTION_API_KEY=your_notion_api_key
```

#### Generate Secrets:
```bash
# Generate SECRET_KEY_BASE
mix phx.gen.secret

# Generate TOKEN_SIGNING_SECRET
mix phx.gen.secret
```

### 2. Database Setup

#### Run Migrations:
```bash
mix ecto.migrate
```

#### Verify Database Extensions:
```sql
-- Ensure citext extension is enabled
CREATE EXTENSION IF NOT EXISTS citext;

-- Verify indexes are created
\d+ users
\d+ sync_configurations
\d+ selected_records
```

### 3. SSL/TLS Configuration

#### Update Production Config:
```elixir
# config/prod.exs
config :sertantai, SertantaiWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  url: [host: "yourdomain.com", port: 443, scheme: "https"],
  check_origin: ["https://yourdomain.com"]
```

### 4. Security Headers

#### Add Security Headers Plug:
```elixir
# lib/sertantai_web/router.ex
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {SertantaiWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
  plug :security_headers
  plug :load_from_session
end

defp security_headers(conn, _opts) do
  conn
  |> put_resp_header("x-frame-options", "DENY")
  |> put_resp_header("x-content-type-options", "nosniff")
  |> put_resp_header("x-xss-protection", "1; mode=block")
  |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
end
```

### 5. Rate Limiting Configuration

#### Configure Rate Limits:
```elixir
# config/prod.exs
config :sertantai, :rate_limiting,
  auth_attempts_per_ip: 5,
  auth_window_minutes: 5,
  sync_operations_per_user: 10,
  sync_window_minutes: 5,
  api_calls_per_user: %{
    airtable: 100,
    notion: 50,
    zapier: 200
  }
```

### 6. Monitoring and Logging

#### Configure Structured Logging:
```elixir
# config/prod.exs
config :logger, :console,
  level: :info,
  format: {Jason, :encode},
  metadata: [:request_id, :user_id, :ip_address]
```

#### Set up Log Rotation:
```bash
# /etc/logrotate.d/sertantai
/var/log/sertantai/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 sertantai sertantai
}
```

### 7. Health Checks

#### Add Health Check Endpoint:
```elixir
# lib/sertantai_web/controllers/health_controller.ex
defmodule SertantaiWeb.HealthController do
  use SertantaiWeb, :controller

  def check(conn, _params) do
    case Ecto.Adapters.SQL.query(Sertantai.Repo, "SELECT 1", []) do
      {:ok, _} -> 
        json(conn, %{status: "healthy", timestamp: DateTime.utc_now()})
      {:error, _} -> 
        conn
        |> put_status(503)
        |> json(%{status: "unhealthy", timestamp: DateTime.utc_now()})
    end
  end
end
```

### 8. Backup Strategy

#### Database Backups:
```bash
# Daily backup script
#!/bin/bash
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d_%H%M%S).sql
aws s3 cp backup_$(date +%Y%m%d_%H%M%S).sql s3://your-backup-bucket/
```

#### Encryption Key Backup:
- Store TOKEN_SIGNING_SECRET in secure key management service
- Document key rotation procedures
- Test restoration procedures

### 9. Container Deployment (Docker)

#### Dockerfile:
```dockerfile
FROM elixir:1.16-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base npm git python3

# Set working directory
WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./
COPY config config
RUN mix local.hex --force && \
    mix local.rebar --force

# Install dependencies
RUN mix deps.get --only=prod
RUN mix deps.compile

# Copy assets
COPY assets assets
RUN npm install --prefix assets
RUN mix assets.deploy

# Copy source code
COPY lib lib
COPY priv priv

# Build release
RUN mix compile
RUN mix release

# Runtime image
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs

# Create app user
RUN addgroup -g 1001 -S sertantai && \
    adduser -S -D -h /app -s /bin/sh -G sertantai -u 1001 sertantai

# Set working directory
WORKDIR /app

# Copy built application
COPY --from=builder --chown=sertantai:sertantai /app/_build/prod/rel/sertantai ./

# Switch to app user
USER sertantai

# Expose port
EXPOSE 4000

# Start application
CMD ["./bin/sertantai", "start"]
```

### 10. Kubernetes Deployment

#### Deployment YAML:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sertantai
spec:
  replicas: 3
  selector:
    matchLabels:
      app: sertantai
  template:
    metadata:
      labels:
        app: sertantai
    spec:
      containers:
      - name: sertantai
        image: sertantai:latest
        ports:
        - containerPort: 4000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: sertantai-secrets
              key: database-url
        - name: SECRET_KEY_BASE
          valueFrom:
            secretKeyRef:
              name: sertantai-secrets
              key: secret-key-base
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 5
          periodSeconds: 5
```

### 11. CI/CD Pipeline

#### GitHub Actions Example:
```yaml
name: Deploy to Production

on:
  push:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Setup Elixir
      uses: erlef/setup-beam@v1
      with:
        elixir-version: '1.16'
        otp-version: '26'
    - name: Install dependencies
      run: mix deps.get
    - name: Run tests
      run: mix test
    - name: Security audit
      run: mix deps.audit

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
    - name: Deploy to production
      run: |
        # Your deployment commands here
        echo "Deploying to production..."
```

### 12. Monitoring Setup

#### Application Monitoring:
```elixir
# Add to application.ex
def start(_type, _args) do
  children = [
    # ... existing children
    {TelemetryMetricsPrometheus, [metrics: metrics()]},
    # ... rest of children
  ]
end

defp metrics do
  [
    # Authentication metrics
    counter("sertantai.auth.attempts.total"),
    counter("sertantai.auth.failures.total"),
    
    # Sync metrics
    counter("sertantai.sync.operations.total"),
    histogram("sertantai.sync.duration.seconds"),
    
    # Rate limiting metrics
    counter("sertantai.rate_limit.violations.total"),
    
    # External API metrics
    counter("sertantai.external_api.calls.total"),
    histogram("sertantai.external_api.response_time.seconds")
  ]
end
```

### 13. Security Hardening

#### Additional Security Measures:
1. **Web Application Firewall (WAF)**
2. **DDoS Protection**
3. **Regular Security Scans**
4. **Dependency Vulnerability Scanning**
5. **SSL Certificate Auto-renewal**

### 14. Performance Optimization

#### Database Optimization:
```sql
-- Add indexes for performance
CREATE INDEX CONCURRENTLY idx_sync_configs_user_active 
ON sync_configurations(user_id, is_active);

CREATE INDEX CONCURRENTLY idx_selected_records_config_status 
ON selected_records(sync_configuration_id, sync_status);
```

#### Connection Pool Configuration:
```elixir
# config/prod.exs
config :sertantai, Sertantai.Repo,
  pool_size: 20,
  timeout: 30_000,
  ownership_timeout: 30_000
```

### 15. Post-Deployment Verification

#### Verification Checklist:
- [ ] Health check endpoint responding
- [ ] Authentication working correctly
- [ ] HTTPS enforced
- [ ] Rate limiting active
- [ ] Monitoring collecting metrics
- [ ] Logs being generated
- [ ] Database migrations applied
- [ ] External API calls working
- [ ] Backup procedures tested

### 16. Incident Response

#### Incident Response Plan:
1. **Detection**: Monitoring alerts
2. **Assessment**: Determine severity
3. **Response**: Execute response procedures
4. **Recovery**: Restore normal operations
5. **Post-incident**: Review and improve

#### Emergency Contacts:
- DevOps Team: devops@company.com
- Security Team: security@company.com
- Database Admin: dba@company.com

---

## Production-Ready Deployment

This guide provides a comprehensive approach to deploying the Sertantai authentication and sync system in a production environment with proper security, monitoring, and operational considerations.

**Last Updated**: Phase 8 Implementation
**Next Review**: After production deployment
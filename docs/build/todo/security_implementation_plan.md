# Security Implementation Plan

This plan outlines the specific steps to implement secure credential management for the Sertantai project as a single developer.

## 🎯 Objectives

1. **Secure Development Environment**: Set up OAuth credentials safely for local development
2. **Production Readiness**: Prepare secure credential management for deployment
3. **Documentation**: Create clear security procedures and emergency protocols
4. **Monitoring**: Implement basic security monitoring and validation

## 📋 Implementation Steps

### Phase 1: Development Environment Setup (30 minutes)

#### Step 1.1: Create Development OAuth Applications
**Time**: 20 minutes

For each OAuth provider, create a development-specific application:

**Google OAuth (5 minutes)**:
```bash
# Visit: https://console.cloud.google.com/
# 1. Create project: "Sertantai Development"
# 2. Enable Google+ API
# 3. Create OAuth 2.0 Client ID
# 4. Set redirect URI: http://localhost:4001/auth/google/callback
# 5. Copy Client ID and Secret
```

**GitHub OAuth (3 minutes)**:
```bash
# Visit: https://github.com/settings/applications/new
# 1. Application name: "Sertantai Local Development"
# 2. Homepage URL: http://localhost:4001
# 3. Callback URL: http://localhost:4001/auth/github/callback
# 4. Copy Client ID and Secret
```

**Azure OAuth (5 minutes)**:
```bash
# Visit: https://portal.azure.com/
# 1. Azure AD → App registrations → New registration
# 2. Name: "Sertantai Development"
# 3. Redirect URI: http://localhost:4001/auth/azure/callback
# 4. Copy Client ID and Secret
```

**LinkedIn OAuth (3 minutes)**:
```bash
# Visit: https://www.linkedin.com/developers/apps
# 1. Create app: "Sertantai Development"
# 2. Redirect URL: http://localhost:4001/auth/linkedin/callback
# 3. Copy Client ID and Secret
```

**OKTA OAuth (2 minutes)**:
```bash
# Visit: https://developer.okta.com/
# 1. Create developer account (free)
# 2. Applications → Create App Integration
# 3. OIDC - Web Application
# 4. Redirect URI: http://localhost:4001/auth/okta/callback
# 5. Copy Client ID, Secret, and your Okta domain
```

**Airtable OAuth (2 minutes)**:
```bash
# Visit: https://airtable.com/developers/web/api/oauth-reference
# 1. Create OAuth app: "Sertantai Development"
# 2. Redirect URL: http://localhost:4001/auth/airtable/callback
# 3. Copy Client ID and Secret
```

#### Step 1.2: Configure Local Environment
**Time**: 10 minutes

**Option A: Using ~/.bashrc (Recommended)**:
```bash
# Add to ~/.bashrc
cat >> ~/.bashrc << 'EOF'

# Sertantai Development OAuth Credentials
export GOOGLE_CLIENT_ID="your-actual-google-client-id"
export GOOGLE_CLIENT_SECRET="your-actual-google-secret"
export GOOGLE_REDIRECT_URI="http://localhost:4001/auth/google/callback"

export GITHUB_CLIENT_ID="your-actual-github-client-id"
export GITHUB_CLIENT_SECRET="your-actual-github-secret"
export GITHUB_REDIRECT_URI="http://localhost:4001/auth/github/callback"

export AZURE_CLIENT_ID="your-actual-azure-client-id"
export AZURE_CLIENT_SECRET="your-actual-azure-secret"
export AZURE_REDIRECT_URI="http://localhost:4001/auth/azure/callback"

export LINKEDIN_CLIENT_ID="your-actual-linkedin-client-id"
export LINKEDIN_CLIENT_SECRET="your-actual-linkedin-secret"
export LINKEDIN_REDIRECT_URI="http://localhost:4001/auth/linkedin/callback"

export OKTA_CLIENT_ID="your-actual-okta-client-id"
export OKTA_CLIENT_SECRET="your-actual-okta-secret"
export OKTA_BASE_URL="https://your-domain.okta.com"
export OKTA_REDIRECT_URI="http://localhost:4001/auth/okta/callback"

export AIRTABLE_CLIENT_ID="your-actual-airtable-client-id"
export AIRTABLE_CLIENT_SECRET="your-actual-airtable-secret"
export AIRTABLE_REDIRECT_URI="http://localhost:4001/auth/airtable/callback"

# Development API Keys
export OPENAI_API_KEY="sk-your-development-openai-key"

# Development Secrets
export SECRET_KEY_BASE="development-secret-key-base-min-64-chars-long-random-string"
export TOKEN_SIGNING_SECRET="development-token-signing-secret-min-64-chars"
EOF

# Reload shell
source ~/.bashrc
```

**Option B: Using direnv (Advanced)**:
```bash
# Install direnv
sudo apt install direnv
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
source ~/.bashrc

# Create .envrc in project root
cd /home/jason/Desktop/sertantai
cat > .envrc << 'EOF'
# Development OAuth Credentials
export GOOGLE_CLIENT_ID="your-actual-google-client-id"
export GOOGLE_CLIENT_SECRET="your-actual-google-secret"
# ... (same as bashrc option)
EOF

# Allow direnv to load
direnv allow
```

### Phase 2: Security Validation (15 minutes)

#### Step 2.1: Test OAuth Configuration
**Time**: 10 minutes

```bash
# Start development server
cd /home/jason/Desktop/sertantai
mix phx.server

# Validate OAuth configuration
mix run -e "IO.inspect(Sertantai.Secrets.validate_oauth_config())"

# Expected output: All providers should show :configured
# %{
#   google: :configured,
#   github: :configured,
#   azure: :configured,
#   linkedin: :configured,
#   okta: :configured,
#   airtable: :configured
# }
```

#### Step 2.2: Test OAuth Flows
**Time**: 5 minutes

```bash
# Open browser to http://localhost:4001
# Try registering with each OAuth provider
# Verify user creation and profile data collection
# Check that UserIdentity records are created
```

### Phase 3: Production Preparation (20 minutes)

#### Step 3.1: Create Production OAuth Applications
**Time**: 15 minutes

Repeat OAuth application creation for production with:
- **Production domains**: `https://yourdomain.com`
- **Production callbacks**: `https://yourdomain.com/auth/{provider}/callback`
- **Separate credentials**: Never reuse development credentials

#### Step 3.2: Production Environment Variables
**Time**: 5 minutes

Document production environment variables needed:
```bash
# Production Environment Variables Template
GOOGLE_CLIENT_ID="prod-google-client-id"
GOOGLE_CLIENT_SECRET="prod-google-secret"
GOOGLE_REDIRECT_URI="https://yourdomain.com/auth/google/callback"

GITHUB_CLIENT_ID="prod-github-client-id"
GITHUB_CLIENT_SECRET="prod-github-secret"
GITHUB_REDIRECT_URI="https://yourdomain.com/auth/github/callback"

# ... etc for all providers

# Production secrets (generate new ones)
SECRET_KEY_BASE="prod-secret-key-base-min-64-chars"
TOKEN_SIGNING_SECRET="prod-token-signing-secret"

# Production database
DATABASE_URL="postgresql://prod-user:prod-pass@prod-host:5432/prod-db"

# Production API keys
OPENAI_API_KEY="sk-prod-openai-key"
```

### Phase 4: Security Monitoring (10 minutes)

#### Step 4.1: Implement Validation Checks
**Time**: 5 minutes

Add to project startup validation:
```elixir
# In lib/sertantai/application.ex (existing file)
def start(_type, _args) do
  # Validate OAuth configuration on startup
  case Mix.env() do
    :prod ->
      validate_production_oauth()
    :dev ->
      validate_development_oauth()
    _ ->
      :ok
  end
  
  # ... existing startup code
end

defp validate_production_oauth do
  config = Sertantai.Secrets.validate_oauth_config()
  
  missing_providers = 
    config
    |> Enum.filter(fn {_provider, status} -> status != :configured end)
    |> Enum.map(fn {provider, _} -> provider end)
  
  if missing_providers != [] do
    Logger.warning("OAuth providers not configured in production: #{inspect(missing_providers)}")
  end
end

defp validate_development_oauth do
  # Warn about placeholder values in development
  if System.get_env("GOOGLE_CLIENT_ID") == "your-google-client-id" do
    Logger.info("OAuth not configured - using placeholder values. See docs/dev/security.md")
  end
end
```

#### Step 4.2: Add Security Headers
**Time**: 5 minutes

Update Phoenix endpoint configuration:
```elixir
# In lib/sertantai_web/endpoint.ex (existing file)
plug Plug.Static, # ... existing config

# Add security headers
plug :put_secure_browser_headers, %{
  "strict-transport-security" => "max-age=31536000; includeSubDomains",
  "x-frame-options" => "DENY",
  "x-content-type-options" => "nosniff",
  "referrer-policy" => "strict-origin-when-cross-origin",
  "permissions-policy" => "camera=(), microphone=(), geolocation=()"
}
```

### Phase 5: Documentation and Procedures (15 minutes)

#### Step 5.1: Create Emergency Procedures
**Time**: 10 minutes

Create `docs/dev/security_incidents.md`:
```markdown
# Security Incident Response

## Credential Compromise Response
1. **Immediate**: Rotate compromised credentials
2. **Within 1 hour**: Check access logs
3. **Within 4 hours**: Update all environments
4. **Within 24 hours**: Review and document incident

## Emergency Contacts
- Developer: [Your contact info]
- OAuth Provider Support: [Provider support links]
- Hosting Provider: [Hosting support]

## Quick Rotation Commands
```bash
# Rotate OAuth secrets
# 1. Generate new secrets in OAuth provider consoles
# 2. Update environment variables
# 3. Restart application
# 4. Verify functionality
```

#### Step 5.2: Add Security Section to README
**Time**: 5 minutes

Update main README.md:
```markdown
## Security

This project implements OAuth authentication with multiple providers. See:
- [Security Guidelines](docs/dev/security.md)
- [Security Implementation Plan](docs/dev/security_implementation_plan.md)
- [Incident Response](docs/dev/security_incidents.md)

For OAuth setup, follow the security guidelines to configure development credentials.
```

## 🔍 Validation Checklist

### Development Environment
- [ ] All 6 OAuth applications created with localhost callbacks
- [ ] Real credentials set in `~/.bashrc` or `.envrc`
- [ ] OAuth validation returns `:configured` for all providers
- [ ] OAuth login flows work for all providers
- [ ] UserIdentity records created successfully
- [ ] Password authentication still works
- [ ] No credentials in git repository

### Production Readiness
- [ ] Production OAuth applications created
- [ ] Production environment variables documented
- [ ] Security headers configured
- [ ] HTTPS redirect configured
- [ ] Error handling for missing credentials
- [ ] Monitoring and logging configured

### Security Measures
- [ ] `.env` contains only placeholder values
- [ ] `.gitignore` excludes all sensitive files
- [ ] Emergency procedures documented
- [ ] Regular credential rotation scheduled
- [ ] Security validation runs on startup

## 🚀 Deployment Considerations

### Environment Variable Management
- **Development**: `~/.bashrc` or `direnv`
- **Staging**: Platform environment variables (Heroku, Railway, etc.)
- **Production**: Secure secret management (AWS Secrets Manager, etc.)

### OAuth Provider Limits
- **Google**: 100 requests/100 seconds per user (generous for development)
- **GitHub**: 5,000 requests/hour per user (generous)
- **LinkedIn**: Varies by application type
- **OKTA**: Depends on plan (developer account has limits)

### Scaling Considerations
- **Multiple Environments**: Each needs separate OAuth apps
- **Team Growth**: Document onboarding for OAuth setup
- **Credential Rotation**: Implement automated rotation for production

## 📊 Success Metrics

- ✅ **Zero credentials in repository**
- ✅ **All OAuth providers functional in development**
- ✅ **Security validation passes**
- ✅ **Documentation complete and accurate**
- ✅ **Emergency procedures tested**

**Estimated Total Time**: 90 minutes
**Priority**: High (security critical)
**Dependencies**: OAuth applications must be created before testing
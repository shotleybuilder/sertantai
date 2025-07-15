# Security Guidelines

This document outlines security best practices for the Sertantai project, with specific focus on credential management, OAuth security, and development workflows.

## 🔐 Credential Management

### Overview
Sertantai uses multiple authentication providers and external services that require secure credential management. This section outlines best practices for handling sensitive information.

### Types of Credentials
- **OAuth Provider Credentials**: Client IDs, secrets for Google, GitHub, Azure, LinkedIn, OKTA, Airtable
- **Database Credentials**: Supabase connection strings, passwords
- **API Keys**: OpenAI, external service integrations
- **Signing Secrets**: JWT tokens, session secrets
- **SSL Certificates**: Production TLS certificates

## 🏗️ Development Environment Security

### Current Implementation
The project uses a layered approach to credential management:

1. **Repository Level**: `.env` file with placeholder values (safe to commit)
2. **Local Environment**: Real credentials in environment variables
3. **Production**: Environment variables in deployment platform

### .env File Strategy
```bash
# .env (tracked in git) - PLACEHOLDER VALUES ONLY
export GOOGLE_CLIENT_ID="your-google-client-id"
export GOOGLE_CLIENT_SECRET="your-google-client-secret"
export GITHUB_CLIENT_ID="your-github-client-id"
# ... etc
```

**✅ Safe to commit**: Contains only placeholder/example values
**🔒 Real credentials**: Managed separately per environment

### Single Developer Setup

#### Option 1: Shell Profile (Recommended)
Add real credentials to `~/.bashrc` or `~/.zshrc`:

```bash
# OAuth Development Credentials
export GOOGLE_CLIENT_ID="123456789-abc.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="GOCSPX-real_development_secret"
export GITHUB_CLIENT_ID="Iv1.real_github_id"
export GITHUB_CLIENT_SECRET="real_github_secret"
export AZURE_CLIENT_ID="real-azure-client-id"
export AZURE_CLIENT_SECRET="real-azure-secret"
export LINKEDIN_CLIENT_ID="real-linkedin-id"
export LINKEDIN_CLIENT_SECRET="real-linkedin-secret"
export OKTA_CLIENT_ID="real-okta-client-id"
export OKTA_CLIENT_SECRET="real-okta-secret"
export OKTA_BASE_URL="https://your-dev.okta.com"
export AIRTABLE_CLIENT_ID="real-airtable-id"
export AIRTABLE_CLIENT_SECRET="real-airtable-secret"

# OpenAI API (for AI features)
export OPENAI_API_KEY="sk-real_openai_key_here"

# Development signing secret
export SECRET_KEY_BASE="development_secret_key_base"
export TOKEN_SIGNING_SECRET="development_token_signing_secret"
```

**Advantages**:
- ✅ Available across all terminal sessions
- ✅ Survives directory changes
- ✅ Simple to manage
- ✅ Not tied to specific projects

**Setup**:
```bash
# Add to ~/.bashrc
echo 'export GOOGLE_CLIENT_ID="your-real-id"' >> ~/.bashrc
# Restart terminal or:
source ~/.bashrc
```

#### Option 2: direnv (Advanced)
Install `direnv` and create `.envrc` in project root:

```bash
# .envrc (gitignored)
export GOOGLE_CLIENT_ID="123456789-abc.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="GOCSPX-real_development_secret"
# ... etc
```

**Advantages**:
- ✅ Auto-loads when entering project directory
- ✅ Project-specific credentials
- ✅ Automatic environment isolation

**Setup**:
```bash
# Install direnv
sudo apt install direnv  # or brew install direnv
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

# In project directory
echo 'export GOOGLE_CLIENT_ID="your-real-id"' > .envrc
direnv allow
```

## 🔑 OAuth Provider Setup

### Development OAuth Applications
Create separate OAuth applications for development (never use production apps for development):

#### Google OAuth Setup
1. Visit [Google Cloud Console](https://console.cloud.google.com/)
2. Create new project: "Sertantai Development"
3. Enable Google+ API
4. Create OAuth 2.0 Client ID
5. Set authorized redirect URI: `http://localhost:4001/auth/google/callback`

#### GitHub OAuth Setup
1. Visit [GitHub Developer Settings](https://github.com/settings/applications/new)
2. Application name: "Sertantai Local Development"
3. Homepage URL: `http://localhost:4001`
4. Authorization callback URL: `http://localhost:4001/auth/github/callback`

#### Azure OAuth Setup
1. Visit [Azure Portal](https://portal.azure.com/)
2. Azure Active Directory → App registrations → New registration
3. Name: "Sertantai Development"
4. Redirect URI: `http://localhost:4001/auth/azure/callback`

#### LinkedIn OAuth Setup
1. Visit [LinkedIn Developer Portal](https://www.linkedin.com/developers/apps)
2. Create app: "Sertantai Development"
3. Redirect URLs: `http://localhost:4001/auth/linkedin/callback`

#### OKTA Setup
1. OKTA Developer Account → Applications → Create App Integration
2. Sign-in method: OIDC - OpenID Connect
3. Application type: Web Application
4. Sign-in redirect URIs: `http://localhost:4001/auth/okta/callback`

#### Airtable OAuth Setup
1. Visit [Airtable Developers](https://airtable.com/developers/web/api/oauth-reference)
2. Create OAuth app: "Sertantai Development"
3. Redirect URL: `http://localhost:4001/auth/airtable/callback`

### Callback URL Pattern
All development OAuth apps should use the pattern:
```
http://localhost:4001/auth/{provider}/callback
```

Where `{provider}` is: `google`, `github`, `azure`, `linkedin`, `okta`, `airtable`

## 🛡️ Security Best Practices

### Credential Rotation
- **OAuth Secrets**: Rotate every 90 days or if compromised
- **Database Passwords**: Rotate every 30 days
- **API Keys**: Monitor usage and rotate if suspicious activity
- **Signing Secrets**: Generate strong secrets, rotate quarterly

### Access Control
- **Principle of Least Privilege**: Grant minimum required permissions
- **OAuth Scopes**: Request only necessary scopes
- **Database Access**: Use service accounts with limited permissions
- **API Rate Limits**: Implement and monitor rate limiting

### Monitoring
- **Failed Login Attempts**: Monitor OAuth failure rates
- **API Usage**: Track unusual API call patterns
- **Database Queries**: Monitor for SQL injection attempts
- **Error Logs**: Review for credential exposure in logs

### Development Security
- **Never commit real credentials** to version control
- **Use HTTPS in production** for all OAuth redirects
- **Validate OAuth state parameters** to prevent CSRF
- **Implement proper session management**
- **Use secure cookie settings** in production

## 🚨 Incident Response

### If Credentials Are Compromised
1. **Immediate Actions**:
   - Rotate affected credentials immediately
   - Revoke OAuth applications if necessary
   - Check logs for unauthorized access
   - Update environment variables

2. **Investigation**:
   - Determine scope of compromise
   - Review access logs
   - Identify affected systems
   - Document timeline of events

3. **Recovery**:
   - Generate new credentials
   - Update all environments
   - Test all affected integrations
   - Monitor for continued issues

### If Credentials Are Accidentally Committed
1. **DO NOT** just delete the commit - it's still in git history
2. **Immediately rotate** the exposed credentials
3. **Use git filter-branch** or BFG Repo-Cleaner to remove from history
4. **Force push** to overwrite remote history (if repository is private)
5. **Notify team members** to re-clone repository

## 📋 Security Checklist

### Before Development
- [ ] OAuth applications created with localhost callbacks
- [ ] Development credentials set in `~/.bashrc` or `.envrc`
- [ ] `.env` file contains only placeholder values
- [ ] `.gitignore` properly excludes sensitive files

### Before Deployment
- [ ] Production OAuth applications configured
- [ ] Production environment variables set
- [ ] HTTPS enabled for all OAuth redirects
- [ ] Security headers configured
- [ ] Rate limiting implemented
- [ ] Monitoring and alerting configured

### Regular Maintenance
- [ ] Review and rotate credentials quarterly
- [ ] Audit OAuth application permissions
- [ ] Review access logs monthly
- [ ] Update dependencies for security patches
- [ ] Test backup and recovery procedures

## 🔍 Security Validation

### Testing OAuth Security
```bash
# Validate OAuth configuration
mix run -e "IO.inspect(Sertantai.Secrets.validate_oauth_config())"

# Test with invalid credentials
export GOOGLE_CLIENT_ID="invalid"
mix phx.server
# Should start but OAuth should fail gracefully
```

### Production Security Checks
- **SSL Certificate Validation**: Ensure HTTPS is properly configured
- **OAuth Redirect Validation**: Verify all redirects use HTTPS
- **Environment Variable Check**: Ensure no credentials in logs
- **Database Connection Security**: Verify encrypted connections

## 📚 References

- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [OAuth 2.0 Security Best Practices](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics)
- [Phoenix Security Guide](https://hexdocs.pm/phoenix/security.html)
- [Ash Authentication Security](https://hexdocs.pm/ash_authentication/security.html)

---

**Last Updated**: July 15, 2025  
**Review Schedule**: Quarterly  
**Next Review**: October 15, 2025
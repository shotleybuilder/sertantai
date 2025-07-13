# Ash Admin Implementation Plan

## Overview

This plan implements Ash Admin for Sertantai following the recommendations from the [Ash Admin Appraisal](./ash_admin_appraisal.md). The implementation is divided into 4 phases with clear testing strategies and success criteria.

## User Role System

The implementation includes a comprehensive role-based access system that aligns with the business model:

### Role Definitions

| Role | Name | Description | Capabilities |
|------|------|-------------|--------------|
| `:guest` | **Visitor** | Unauthenticated users browsing the platform | • Browse legal register records<br>• View public information<br>• Cannot perform applicability screening |
| `:member` | **Basic Member** | Registered users with free account | • Browse legal register records<br>• Basic applicability screening (no AI)<br>• Cannot sync to external tools<br>• Limited organization/location management |
| `:professional` | **Professional** | Paid subscription users | • All Basic Member capabilities<br>• AI-powered applicability screening<br>• Sync to external tools (Airtable, Notion, Zapier)<br>• Full organization/location management<br>• Advanced features and analytics |
| `:admin` | **Administrator** | Internal admin users | • Full system access<br>• User management<br>• System configuration<br>• Billing management<br>• Data administration |
| `:support` | **Support Team** | Customer support staff | • Read access to user data<br>• Limited user assistance<br>• Cannot modify billing/system settings<br>• Audit trail access |

### Role Hierarchy & Permissions

```
Admin > Support > Professional > Member > Guest
```

- **Inheritance**: Higher roles inherit capabilities from lower roles
- **Default Role**: New users start as `:guest`, upgrade to `:member` upon registration
- **Billing Integration**: Role upgrades tied to Stripe subscription status
- **Security**: Role changes audited and require appropriate permissions

## Phase 1: Basic Setup & Foundation
**Timeline: 1-2 days**
**Status: 📋 TO DO**

### Objectives
- Install and configure Ash Admin
- Set up basic admin interface for existing resources
- Establish routing and domain configuration

### Key Steps
1. **Dependency Installation**
   - Add `ash_admin` to `mix.exs`
   - Run dependency installation and setup

2. **Domain Configuration**
   - Update `Sertantai.Domain` with `AshAdmin.Domain` extension
   - Update `Sertantai.Organizations` domain with admin configuration
   - Update `Sertantai.Sync` domain with admin configuration

3. **Resource Configuration**
   - Add `AshAdmin.Resource` extension to key resources:
     - `Sertantai.Accounts.User`
     - `Sertantai.Organizations.Organization`
     - `Sertantai.Sync.SyncConfiguration`

4. **Basic Routing**
   - Add `/admin` route in router
   - Configure basic access (no authentication yet)

### Testing Strategy
- **Manual Testing**: Access `/admin` and verify all resources are visible
- **Resource Verification**: Confirm all 14 Ash resources appear in admin interface
- **Basic CRUD**: Test create, read, update operations on non-sensitive resources

### Success Criteria
- [ ] Admin interface accessible at `/admin`
- [ ] All domains and resources visible in admin navigation
- [ ] Basic CRUD operations work for Users and Organizations
- [ ] No console errors or warnings
- [ ] Encrypted credentials in SyncConfiguration remain protected

---

## Phase 2: Authentication & Basic Security
**Timeline: 2-3 days**
**Status: 📋 TO DO**

### Objectives
- Secure admin routes with existing authentication
- Implement basic access control
- Ensure proper session handling

### Key Steps
1. **Route Security**
   - Add `:require_authenticated_user` pipeline to admin routes
   - Test authentication redirection for unauthenticated users

2. **Session Integration**
   - Verify AshAuthentication integration with admin interface
   - Test actor assignment for admin operations

3. **Basic Access Control**
   - Implement temporary admin access based on user email domain
   - Add basic audit logging for admin actions

4. **Security Testing**
   - Test unauthorized access scenarios
   - Verify sensitive data protection

### Testing Strategy
- **Authentication Tests**: Verify unauthenticated users are redirected
- **Session Tests**: Confirm authenticated users can access admin
- **Security Tests**: Attempt access with different user types
- **Data Protection**: Verify encrypted fields remain secure

### Success Criteria
- [ ] Unauthenticated users cannot access `/admin`
- [ ] Authenticated users can access admin interface
- [ ] User context preserved throughout admin operations
- [ ] Sensitive credentials remain encrypted and hidden
- [ ] Audit trail captures admin actions

---

## Phase 3: Role-Based Authorization
**Timeline: 3-4 days**
**Status: 📋 TO DO**

### Objectives
- Implement proper role-based access control
- Create admin user roles and permissions
- Secure resource-level access

### Key Steps
1. **User Role System**
   - Add `role` attribute to User resource with enum: `[:guest, :member, :professional, :admin, :support]`
   - Create migration for role field with default `:guest`
   - Implement role-based policies using Ash.Policy.Authorizer
   - Add role validation and constraints

2. **Admin Authorization**
   - Create `require_admin_user` plug (`:admin` and `:support` roles only)
   - Implement Ash.Policy.Authorizer for admin resources
   - Configure resource-level permissions based on role hierarchy
   - Separate admin access from regular user permissions

3. **Role Management**
   - Admin interface for managing user roles
   - Role upgrade/downgrade workflows
   - Business logic for role transitions (guest → member → professional)
   - Role-based resource visibility and field access

4. **Security Policies**
   - Prevent unauthorized role escalation
   - Implement field-level permissions (e.g., support can read but not modify billing)
   - Audit all admin privilege changes
   - Role-based action restrictions

### Testing Strategy
- **Role Tests**: Verify all 5 roles (guest, member, professional, admin, support) have appropriate access
- **Permission Tests**: Test resource-level access controls for each role
- **Business Logic Tests**: Verify role transition workflows (guest→member→professional)
- **Privilege Escalation**: Attempt unauthorized role changes between all role combinations
- **Policy Tests**: Verify Ash policies work correctly for role hierarchy
- **Admin Interface Tests**: Test admin/support access to user management features

### Success Criteria
- [ ] Only users with `:admin` and `:support` roles can access admin interface
- [ ] Role hierarchy enforced (admin > support > professional > member > guest)
- [ ] Business model roles work correctly (member = basic, professional = paid)
- [ ] Role changes properly audited with user tracking
- [ ] Support role has read access but limited write permissions
- [ ] Policies prevent unauthorized role escalation
- [ ] Default role assignment works for new users (:guest → :member on registration)

---

## Phase 4: Stripe Integration & Billing Management
**Timeline: 5-7 days**
**Status: 📋 TO DO**

### Objectives
- Integrate Stripe for payment processing
- Create billing-related Ash resources
- Admin interface for subscription management

### Key Steps
1. **Stripe Setup**
   - Add `stripity_stripe` dependency
   - Configure Stripe API keys and webhooks
   - Set up development/production environments

2. **Billing Resources**
   - Create `Billing.Customer` resource
   - Create `Billing.Subscription` resource  
   - Create `Billing.Payment` resource
   - Create `Billing.Plan` resource
   - Link subscription status to user roles (professional = active subscription)

3. **Admin Integration**
   - Add billing resources to admin interface
   - Configure admin actions for billing operations
   - Implement subscription management workflows

4. **Webhook Handling & Role Integration**
   - Stripe webhook endpoint for payment events
   - Update resource states based on Stripe events
   - Automatic role upgrades/downgrades based on subscription status
   - Professional role assignment on successful payment
   - Role downgrade to member on subscription cancellation/failure
   - Error handling and retry logic

### Testing Strategy
- **Stripe Tests**: Test API integration with Stripe test environment
- **Resource Tests**: Verify billing resources work correctly
- **Webhook Tests**: Test webhook processing and state updates
- **Role Integration Tests**: Verify automatic role changes based on subscription status
- **Integration Tests**: End-to-end billing workflows (member → professional → member)
- **Admin Tests**: Verify admin can manage subscriptions and view role changes

### Success Criteria
- [ ] Stripe integration working in test mode
- [ ] Billing resources visible and manageable in admin
- [ ] Webhook processing updates resource states correctly
- [ ] Automatic role upgrades work (member → professional on payment success)
- [ ] Automatic role downgrades work (professional → member on subscription end)
- [ ] Admin can create/modify/cancel subscriptions
- [ ] Payment history and status visible in admin
- [ ] Role change audit trail linked to billing events
- [ ] Error handling works for failed payments and role transitions

---

## Overall Testing Strategy

### Automated Testing
```bash
# Run after each phase
mix test
mix ash.codegen --check
mix ecto.migrate
PORT=4001 mix phx.server  # Test on port 4001 per guidelines
```

### Manual Testing Checklist
- [ ] Admin interface loads without errors
- [ ] All resources accessible to authorized users
- [ ] CRUD operations work correctly
- [ ] Authentication and authorization working
- [ ] No sensitive data leaks
- [ ] Performance acceptable with existing data

### Security Testing
- [ ] Unauthorized access attempts blocked
- [ ] Session handling secure
- [ ] Role escalation prevented
- [ ] SQL injection protection (via Ash)
- [ ] CSRF protection active

### Performance Testing
- [ ] Admin interface responsive with 19K+ UK LRT records
- [ ] Resource pagination working
- [ ] Search functionality performs well
- [ ] No memory leaks in long sessions

---

## Risk Mitigation

### High Priority Risks
1. **Security Misconfiguration**
   - Mitigation: Thorough testing of authentication/authorization
   - Regular security reviews

2. **Performance Issues**
   - Mitigation: Test with production data volume
   - Implement pagination and filtering

3. **Data Integrity**
   - Mitigation: Leverage existing Ash validations
   - Comprehensive testing of CRUD operations

### Medium Priority Risks
1. **CSP Configuration**
   - Mitigation: Update CSP headers as needed
   - Test admin interface functionality

2. **Role Management Complexity**
   - Mitigation: Start simple, iterate based on needs
   - Clear documentation of role permissions

---

## Success Metrics

### Phase 1 Success
- Basic admin interface functional
- All resources accessible
- No critical bugs

### Phase 2 Success
- Authentication working correctly
- Basic security measures in place
- Audit logging functional

### Phase 3 Success
- Role-based access control working
- Proper authorization policies
- Admin can manage user roles

### Phase 4 Success
- Stripe integration complete
- Billing management functional
- Admin can handle subscriptions

### Overall Project Success
- Reduced admin development time by 80%+
- Secure, maintainable admin interface
- Support team can manage users and billing
- Foundation for future admin features

---

## Post-Implementation

### Monitoring
- Admin usage analytics
- Performance monitoring
- Security incident tracking
- User feedback collection

### Future Enhancements
- Custom admin dashboards
- Advanced reporting features
- Bulk operations
- API access for admin functions

### Maintenance
- Regular security updates
- Performance optimization
- Feature additions based on user needs
- Documentation updates
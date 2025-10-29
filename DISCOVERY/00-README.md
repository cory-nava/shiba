# SHIBA Discovery Documentation

## Overview

This folder contains comprehensive technical discovery documentation for the SHIBA (State Hosted Integrated Benefits Application) repository. The purpose of this discovery is to analyze how to transform SHIBA from a Minnesota-specific benefits application into a configurable, open-source platform that any state can use for their Income & Expense (IE&E) benefits system.

## What is SHIBA?

SHIBA is a Spring Boot-based web application that enables residents to apply for state benefit programs including:
- **SNAP** (Supplemental Nutrition Assistance Program)
- **CCAP** (Child Care Assistance Program)
- **CASH** (General Assistance / Emergency Assistance)
- **GRH** (Group Residential Housing)
- **EA** (Emergency Assistance)
- **State-specific programs** (e.g., Minnesota's CERTAIN_POPS)

Currently implemented for Minnesota with tight integration to Minnesota's state systems.

## Discovery Documents

### Core Documentation

1. **[01-ARCHITECTURE-OVERVIEW.md](./01-ARCHITECTURE-OVERVIEW.md)**
   - Technology stack (Spring Boot, Java 17, PostgreSQL, Thymeleaf)
   - Application architecture and patterns
   - Entry points and key controllers
   - Security architecture
   - Deployment model

2. **[02-STATE-SPECIFIC-LOGIC.md](./02-STATE-SPECIFIC-LOGIC.md)**
   - Hardcoded Minnesota values (87 counties, 11 tribal nations)
   - Geographic configuration
   - Program definitions
   - MNIT FileNet integration specifics
   - Time zone, email, and localization settings
   - Feature flags

3. **[03-DATABASE-SCHEMA.md](./03-DATABASE-SCHEMA.md)**
   - PostgreSQL database structure
   - Core tables: `applications`, `application_status`
   - Session management (Spring Session JDBC)
   - JSONB application data structure
   - Encryption and PII masking
   - Common queries and access patterns
   - Multi-state adaptation notes

4. **[04-API-ENDPOINTS.md](./04-API-ENDPOINTS.md)**
   - Public endpoints (citizen-facing application flow)
   - Admin endpoints (state staff)
   - OAuth2 authentication
   - External API integrations (MNIT FileNet, Mailgun, SmartyStreets, Azure Blob)
   - Page flow configuration
   - Error handling

5. **[05-CONFIGURATION-REQUIREMENTS.md](./05-CONFIGURATION-REQUIREMENTS.md)**
   - Current environment-based configuration
   - Required configuration dimensions for multi-state support:
     - Geographic (counties/regions)
     - Programs
     - Document types
     - Integrations
     - Business rules
     - Localization
     - Authentication
   - Configuration management strategies (file-based, database-driven, hybrid)
   - Migration path from MN-specific to multi-state

6. **[06-INTEGRATION-MAPPING.md](./06-INTEGRATION-MAPPING.md)**
   - External service integrations:
     - Document submission (MNIT FileNet SOAP)
     - Email service (Mailgun)
     - Address validation (SmartyStreets)
     - Document storage (Azure Blob)
     - Analytics (Mixpanel)
     - Error tracking (Sentry)
   - Proposed abstraction interfaces for each integration
   - Implementation options for multi-provider support
   - Integration health checks

7. **[07-MULTI-STATE-ADAPTATION-PLAN.md](./07-MULTI-STATE-ADAPTATION-PLAN.md)**
   - **Executive summary and roadmap**
   - 8-phase implementation plan:
     - Phase 1: Extract Minnesota-specific logic (4-6 weeks)
     - Phase 2: Integration abstraction layer (6-8 weeks)
     - Phase 3: Database multi-tenancy (3-4 weeks)
     - Phase 4: Form engine configurability (8-10 weeks)
     - Phase 5: Business rules externalization (4-6 weeks)
     - Phase 6: Admin UI for configuration (10-12 weeks)
     - Phase 7: Documentation and onboarding (4-6 weeks)
     - Phase 8: Testing and QA (ongoing)
   - Timeline: 6-8 months with parallel work streams
   - Risks and mitigation strategies
   - Success metrics

### Schema Files

8. **[schema/database-schema.sql](./schema/database-schema.sql)**
   - Complete PostgreSQL schema
   - All tables with column definitions
   - Indexes and constraints
   - Triggers and functions
   - Sample queries
   - Multi-state adaptation notes

9. **[schema/api-schema.yaml](./schema/api-schema.yaml)**
   - OpenAPI 3.0 specification
   - All HTTP endpoints documented
   - Request/response schemas
   - Authentication schemes
   - Data models (Application, ApplicationStatus, etc.)

## Key Findings

### Current State (Minnesota-Specific)

**Hardcoded Elements:**
- ✗ 87 Minnesota counties (Java enum)
- ✗ 11 tribal nations (Java enum)
- ✗ 6 programs with Minnesota-specific names
- ✗ MNIT FileNet SOAP integration
- ✗ Mailgun email domain (mail.mnbenefits.mn.gov)
- ✗ Time zone (America/Chicago)
- ✗ 9 hardcoded admin email addresses
- ✗ County/tribal routing logic
- ✗ Expedited eligibility rules for Minnesota thresholds
- ✗ Document types (CAF, CCAP specific to Minnesota)

**What Works Well:**
- ✓ Flexible JSONB data storage (application_data)
- ✓ Event-driven architecture (ApplicationSubmittedEvent)
- ✓ Retry logic with exponential backoff
- ✓ Session management (JDBC-backed, multi-instance capable)
- ✓ Encryption (AES256_GCM for PII)
- ✓ Comprehensive testing infrastructure
- ✓ Document generation (PDFBox)
- ✓ Accessibility compliance (WCAG 2.1 AA)

### Target State (Multi-State)

**Architecture Vision:**
- Database-driven tenant configuration
- Plugin architecture for integrations (adapters for SOAP, REST, SFTP, email)
- Configurable form engine per state
- Externalized business rules (rules engine)
- Admin UI for non-technical configuration
- Comprehensive onboarding documentation

**Deployment Models:**
1. **Multi-tenant SaaS** - Single deployment serving multiple states
2. **Isolated instances** - Each state runs their own deployment
3. **Hybrid** - Shared infrastructure with tenant isolation

## Technical Debt & Risks

### High Priority
1. **Tight coupling to MNIT FileNet** - Major refactoring needed
2. **Hardcoded County/TribalNation enums** - Referenced in ~50+ files
3. **Form configuration** - 3000+ line YAML file with MN-specific logic
4. **Eligibility rules** - Complex hardcoded business logic

### Medium Priority
5. **Email domain configuration** - Scattered across codebase
6. **Time zone handling** - Single hardcoded value
7. **Admin access control** - Hardcoded email list

### Low Priority
8. **Analytics provider** - Mixpanel specific but low impact
9. **Address validation** - SmartyStreets specific but has fallback

## Recommended Next Steps

### Immediate (Weeks 1-4)
1. **Review and validate** this discovery with stakeholders
2. **Identify pilot state** - Recommend a small/medium state with simpler requirements than Minnesota
3. **Set up project board** with 8 phases broken into tasks
4. **Begin Phase 1** - Extract County enum to configuration as proof of concept
5. **Set up CI/CD** for multi-tenant testing

### Short Term (Months 2-4)
6. **Complete Phase 1** - All Minnesota-specific logic extracted to configuration
7. **Implement Phase 3** - Add tenant tables to database
8. **Migrate Minnesota** to use new tenant-based configuration (validate backwards compatibility)
9. **Design adapter interfaces** for Phase 2

### Medium Term (Months 5-8)
10. **Complete Phase 2** - Integration adapters for common patterns (REST API, SFTP, email)
11. **Build Phase 4** - Tenant-specific form configuration
12. **Phase 5** - Business rules engine
13. **Pilot state deployment** - Get real-world feedback

### Long Term (Months 9-12)
14. **Phase 6** - Admin UI (informed by pilot learnings)
15. **Phase 7** - Comprehensive documentation
16. **Refine based on pilot** - Address gaps discovered
17. **Open source release** - Public repository with clear governance
18. **Community building** - Forums, Slack, contribution guidelines

## Estimated Effort

**Full transformation:** 6-8 months with 3-4 person team

**Breakdown:**
- 1 Senior Backend Engineer (architecture, core refactoring)
- 1 Full-Stack Engineer (admin UI, integration adapters)
- 1 QA Engineer (testing strategy, multi-tenant testing)
- 0.5 Product Manager (state onboarding, documentation)

## Success Criteria

### Technical
- [ ] Minnesota continues working without issues (100% backwards compatibility)
- [ ] Second state deployed within 2 weeks of configuration
- [ ] <100ms latency added for tenant config lookup
- [ ] All integration tests passing for multi-tenant scenarios

### Business
- [ ] 3+ states using SHIBA within 12 months
- [ ] Deployment time: months → weeks
- [ ] Maintenance cost reduction (shared codebase vs custom)

### Community
- [ ] Public GitHub repository with Apache 2.0 or MIT license
- [ ] Comprehensive documentation (setup, configuration, contribution)
- [ ] Active community (forum/Slack)
- [ ] 5+ external contributors

## Questions to Address

### Before Starting
1. **Commitment** - Does Minnesota want to maintain backwards compatibility or can we make breaking changes?
2. **Governance** - Who owns the open-source project? Code for America? Consortium of states?
3. **Funding** - Is there budget for this transformation work?
4. **Pilot state** - Which state is interested in being the second implementation?
5. **Timeline** - Is 6-8 months acceptable or is there pressure for faster delivery?

### During Development
6. **Feature parity** - Do all states need all features (document upload, expedited eligibility, etc.)?
7. **Customization** - How much custom code can states add vs configuration only?
8. **Hosting** - Centralized hosting or each state self-hosts?
9. **Support** - Who provides technical support for states?
10. **Upgrades** - How do states upgrade to new versions?

## How to Use This Discovery

### For Developers
- Start with `01-ARCHITECTURE-OVERVIEW.md` to understand the system
- Read `07-MULTI-STATE-ADAPTATION-PLAN.md` for implementation roadmap
- Reference `schema/` files for database and API details
- Use `06-INTEGRATION-MAPPING.md` when building adapters

### For Product/Project Managers
- Start with `07-MULTI-STATE-ADAPTATION-PLAN.md` for timeline and effort
- Review risks and success criteria
- Use this to create project plan and secure resources
- Reference for stakeholder communications

### For State Partners
- Read `02-STATE-SPECIFIC-LOGIC.md` to understand what needs configuration
- Review `05-CONFIGURATION-REQUIREMENTS.md` to see what you'll need to provide
- `07-MULTI-STATE-ADAPTATION-PLAN.md` section "State Onboarding Checklist"

### For Architects
- `01-ARCHITECTURE-OVERVIEW.md` for current architecture
- `06-INTEGRATION-MAPPING.md` for proposed abstractions
- `schema/database-schema.sql` for data model
- `07-MULTI-STATE-ADAPTATION-PLAN.md` Phases 2-3 for integration and database architecture

## Contributing to Discovery

This is a living document. As development progresses:

1. **Update findings** - Add lessons learned from implementation
2. **Refine estimates** - Adjust time estimates based on actual progress
3. **Document decisions** - Add Architecture Decision Records (ADRs)
4. **Track changes** - Keep discovery in sync with codebase

## Contact

For questions about this discovery:
- Create an issue in the repository
- Reference specific discovery document and section
- Tag with `discovery` label

---

**Last Updated:** 2025-10-28
**Discovery Version:** 1.0
**Status:** Complete - Ready for implementation planning

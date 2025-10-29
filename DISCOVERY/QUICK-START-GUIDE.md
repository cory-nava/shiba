# Quick Start Guide - SHIBA Discovery

**New to this discovery?** Start here for a 10-minute overview.

---

## TL;DR

**What is this?** Complete technical analysis of transforming SHIBA (Minnesota's benefits application) into a multi-state, cloud-agnostic platform.

**Timeline:** 6-8 months, $525-675K

**Next step:** Review this guide → Read Executive Summary → Approve POC

---

## 5-Minute Overview

### What SHIBA Does

Minnesota residents use SHIBA to apply online for:
- SNAP (food assistance)
- CCAP (child care help)
- CASH (financial assistance)
- Other state benefits

It works well, but it's **hardcoded for Minnesota**.

### The Goal

Make SHIBA work for **any state** with their own:
- Counties/regions
- Benefit programs
- Document submission systems
- Cloud infrastructure (AWS, Azure, GCP, or on-premises)

### The Plan

**8 phases over 6-8 months:**
1. Extract Minnesota-specific config → YAML/database
2. Build plugin system for state integrations
3. Add multi-state database support
4. Deploy to pilot state (validate it works)
5. Externalize business rules
6. Build admin UI for easy configuration
7. Write comprehensive docs
8. Open source release

### The Investment

- **Team:** 3-4 people (backend, frontend, QA, PM)
- **Cost:** $525-675K
- **Timeline:** 6-8 months
- **ROI:** Save $1.5M+ per state, reach 50 states

---

## 10-Minute Deep Dive

### Current Architecture

```
┌─────────────┐
│   User      │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────┐
│  Spring Boot App (Minnesota)    │
│  - 87 counties (hardcoded)      │
│  - MNIT FileNet (hardcoded)     │
│  - Azure Blob (hardcoded)       │
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────┐
│ PostgreSQL  │
└─────────────┘
```

### Target Architecture

```
┌─────────────┐  ┌─────────────┐
│  MN User    │  │  CA User    │
└──────┬──────┘  └──────┬──────┘
       │                │
       └────────┬───────┘
                ▼
┌─────────────────────────────────────┐
│  Spring Boot App (Multi-Tenant)     │
│  - Tenant detection                 │
│  - Load MN or CA config             │
│  - Plugin adapters (SOAP/REST/SFTP) │
│  - Cloud-agnostic storage           │
└──────┬──────────────────────────────┘
       │
       ▼
┌──────────────────────────────┐
│ PostgreSQL (Multi-Tenant)    │
│  - tenants table             │
│  - regions table (per state) │
│  - programs table            │
└──────────────────────────────┘
```

### Key Changes

| Component | Current (MN-specific) | Target (Multi-state) |
|-----------|----------------------|---------------------|
| **Counties** | Hardcoded enum (87) | Database config |
| **Programs** | Hardcoded (6) | Per-tenant config |
| **Document Submission** | MNIT SOAP only | Plugin adapters (SOAP, REST, SFTP, email) |
| **Storage** | Azure Blob only | AWS S3, Azure, GCS, MinIO, local |
| **Database** | PostgreSQL | PostgreSQL (any cloud) |
| **Email** | Mailgun only | Multiple providers |

### What Stays the Same

✅ Core form engine
✅ PDF generation
✅ Encryption
✅ Session management
✅ Testing framework
✅ Accessibility features

**Minnesota keeps working** throughout transformation.

---

## Who Should Read What?

### Executive / Decision Maker
**Time:** 15 minutes
1. 📄 [EXECUTIVE-SUMMARY.md](./EXECUTIVE-SUMMARY.md) - Business case, budget, timeline
2. 📄 [08-RECOMMENDED-FOCUS-AREAS.md](./08-RECOMMENDED-FOCUS-AREAS.md) - What to do first

**Key Questions Answered:**
- Why should we do this?
- How much will it cost?
- How long will it take?
- What's the ROI?

### Product Manager / Project Manager
**Time:** 30 minutes
1. 📄 [EXECUTIVE-SUMMARY.md](./EXECUTIVE-SUMMARY.md) - Overview
2. 📄 [07-MULTI-STATE-ADAPTATION-PLAN.md](./07-MULTI-STATE-ADAPTATION-PLAN.md) - Detailed roadmap
3. 📄 [08-RECOMMENDED-FOCUS-AREAS.md](./08-RECOMMENDED-FOCUS-AREAS.md) - Priorities
4. 📄 [05-CONFIGURATION-REQUIREMENTS.md](./05-CONFIGURATION-REQUIREMENTS.md) - What states need to configure

**Key Questions Answered:**
- What are the phases?
- What resources do we need?
- What are the risks?
- How do we onboard states?

### Software Architect
**Time:** 1 hour
1. 📄 [01-ARCHITECTURE-OVERVIEW.md](./01-ARCHITECTURE-OVERVIEW.md) - Tech stack
2. 📄 [ARCHITECTURE-MERMAID.md](./ARCHITECTURE-MERMAID.md) - System diagrams
3. 📄 [06-INTEGRATION-MAPPING.md](./06-INTEGRATION-MAPPING.md) - Integration patterns
4. 📄 [09-CLOUD-PROVIDER-ABSTRACTION.md](./09-CLOUD-PROVIDER-ABSTRACTION.md) - Cloud strategy
5. 📄 [diagrams/](./diagrams/) - Detailed sub-diagrams

**Key Questions Answered:**
- How is it architected today?
- What's the target architecture?
- How do we abstract integrations?
- How do we support multiple clouds?

### Backend Engineer
**Time:** 1-2 hours
1. 📄 [02-STATE-SPECIFIC-LOGIC.md](./02-STATE-SPECIFIC-LOGIC.md) - What's hardcoded
2. 📄 [03-DATABASE-SCHEMA.md](./03-DATABASE-SCHEMA.md) - Database structure
3. 📄 [04-API-ENDPOINTS.md](./04-API-ENDPOINTS.md) - API documentation
4. 📄 [06-INTEGRATION-MAPPING.md](./06-INTEGRATION-MAPPING.md) - Adapter patterns
5. 📄 [schema/database-schema.sql](./schema/database-schema.sql) - SQL schema

**Key Questions Answered:**
- What needs to be refactored?
- How does multi-tenancy work?
- How do adapters work?
- What's the database schema?

### State Partner (Adopting SHIBA)
**Time:** 30 minutes
1. 📄 [EXECUTIVE-SUMMARY.md](./EXECUTIVE-SUMMARY.md) - What SHIBA is
2. 📄 [05-CONFIGURATION-REQUIREMENTS.md](./05-CONFIGURATION-REQUIREMENTS.md) - What you need to provide
3. 📄 [09-CLOUD-PROVIDER-ABSTRACTION.md](./09-CLOUD-PROVIDER-ABSTRACTION.md) - Cloud options
4. 📄 Section "State Onboarding Checklist" in [07-MULTI-STATE-ADAPTATION-PLAN.md](./07-MULTI-STATE-ADAPTATION-PLAN.md)

**Key Questions Answered:**
- What do I need to configure?
- Can I use my existing cloud provider?
- What integrations are supported?
- How long does deployment take?

---

## Key Files Quick Reference

### Must Read (Everyone)
- 📄 **EXECUTIVE-SUMMARY.md** - Start here
- 📄 **00-README.md** - Navigation and overview
- 📄 **08-RECOMMENDED-FOCUS-AREAS.md** - What to do next

### Architecture & Design
- 📄 **01-ARCHITECTURE-OVERVIEW.md** - Current tech stack
- 📄 **ARCHITECTURE-MERMAID.md** - Visual diagrams
- 📄 **09-CLOUD-PROVIDER-ABSTRACTION.md** - Cloud-agnostic design

### State-Specific Analysis
- 📄 **02-STATE-SPECIFIC-LOGIC.md** - What's hardcoded for Minnesota
- 📄 **05-CONFIGURATION-REQUIREMENTS.md** - What needs to be configurable

### Technical Details
- 📄 **03-DATABASE-SCHEMA.md** - Database structure
- 📄 **04-API-ENDPOINTS.md** - API documentation
- 📄 **06-INTEGRATION-MAPPING.md** - External integrations

### Implementation
- 📄 **07-MULTI-STATE-ADAPTATION-PLAN.md** - 8-phase roadmap
- 📄 **schema/** - Database and API schemas
- 📄 **diagrams/** - Detailed component diagrams

---

## Common Questions

### Q: Will this break Minnesota?
**A:** No. 100% backwards compatibility is a hard requirement. Comprehensive testing before any changes go live.

### Q: How long to deploy a new state after this is done?
**A:** 2-4 weeks of configuration vs 6-12 months to build from scratch.

### Q: What if a state has unique requirements?
**A:** Flexible config (JSONB), plugin architecture, and ability to create custom adapters.

### Q: Can states use their existing cloud provider?
**A:** Yes! Abstracted to support AWS, Azure, GCP, and on-premises.

### Q: What if a state doesn't have an API?
**A:** We support email and SFTP as fallback options.

### Q: How much will it cost a state to adopt SHIBA?
**A:** ~$50-100K for configuration and deployment vs $500K-2M to build custom.

### Q: Is this open source?
**A:** Will be after transformation. Public repository with clear governance.

### Q: What if the POC doesn't work out?
**A:** Minimal investment (~$50K, 4-6 weeks). Easy early exit if approach doesn't work.

---

## Next Steps

### If you're a decision maker:
1. ✅ Read **EXECUTIVE-SUMMARY.md** (15 min)
2. ✅ Review budget and timeline
3. ✅ Decide on POC approval
4. ✅ Schedule stakeholder meeting

### If you're implementing:
1. ✅ Read architecture docs (1-2 hours)
2. ✅ Review **07-MULTI-STATE-ADAPTATION-PLAN.md** phases
3. ✅ Familiarize with codebase
4. ✅ Prepare for POC kickoff

### If you're a potential state partner:
1. ✅ Read **EXECUTIVE-SUMMARY.md**
2. ✅ Review **05-CONFIGURATION-REQUIREMENTS.md**
3. ✅ Assess your integration needs
4. ✅ Contact project team to discuss partnership

---

## Discovery Statistics

- **Total Files:** 16 documents
- **Total Size:** 280KB of documentation
- **Diagrams:** 25+ Mermaid diagrams
- **Coverage:** Architecture, database, API, configuration, deployment, security, migration
- **Time to Read:**
  - Quick overview: 10 minutes (this guide)
  - Executive summary: 15 minutes
  - Technical deep dive: 2-3 hours
  - Complete review: 4-6 hours

---

## Help & Support

**Questions about the discovery?**
- Create an issue in the repository
- Tag with `discovery` label
- Reference specific document and section

**Questions about implementation?**
- Review **07-MULTI-STATE-ADAPTATION-PLAN.md** phases
- Check **08-RECOMMENDED-FOCUS-AREAS.md** for priorities
- Consult architecture diagrams in **ARCHITECTURE-MERMAID.md**

---

## Document Structure Overview

```
DISCOVERY/
├── QUICK-START-GUIDE.md          ← You are here
├── EXECUTIVE-SUMMARY.md           ← Read next
├── 00-README.md                   ← Full navigation
│
├── Core Analysis
│   ├── 01-ARCHITECTURE-OVERVIEW.md
│   ├── 02-STATE-SPECIFIC-LOGIC.md
│   ├── 03-DATABASE-SCHEMA.md
│   ├── 04-API-ENDPOINTS.md
│   └── 05-CONFIGURATION-REQUIREMENTS.md
│
├── Integration & Cloud
│   ├── 06-INTEGRATION-MAPPING.md
│   └── 09-CLOUD-PROVIDER-ABSTRACTION.md
│
├── Implementation
│   ├── 07-MULTI-STATE-ADAPTATION-PLAN.md
│   └── 08-RECOMMENDED-FOCUS-AREAS.md
│
├── Diagrams
│   ├── ARCHITECTURE-DIAGRAM.md (text-based)
│   ├── ARCHITECTURE-MERMAID.md (Mermaid format)
│   └── diagrams/
│       ├── 01-storage-abstraction.md
│       └── 02-tenant-context.md
│
└── Schemas
    ├── schema/database-schema.sql
    └── schema/api-schema.yaml
```

---

**Ready to dive in?** → [EXECUTIVE-SUMMARY.md](./EXECUTIVE-SUMMARY.md)

**Last Updated:** October 28, 2025

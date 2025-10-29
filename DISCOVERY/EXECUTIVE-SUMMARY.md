# Executive Summary - SHIBA Multi-State Transformation

## Project Vision

Transform SHIBA (State Hosted Integrated Benefits Application) from a Minnesota-specific benefits application into a **configurable, cloud-agnostic, open-source platform** that any state can deploy for their Income & Expense (IE&E) benefits programs.

---

## Current State Assessment

### What SHIBA Is Today

SHIBA is a production-ready Spring Boot web application enabling Minnesota residents to apply for state benefits (SNAP, CCAP, CASH, GRH, EA, CERTAIN_POPS). It's well-architected with:

✅ **Strong Foundation**
- Event-driven architecture
- Encrypted JSONB data storage
- Comprehensive testing (unit, integration, a11y)
- Retry logic with exponential backoff
- Accessibility compliance (WCAG 2.1 AA)
- Multi-instance capable (JDBC session store)

### Key Constraints

❌ **Minnesota-Specific Hardcoding**
- 87 counties (Java enum)
- 11 tribal nations (Java enum)
- MNIT FileNet SOAP integration
- 6 program definitions
- Admin email addresses
- Time zone (America/Chicago)
- Email domain (mail.mnbenefits.mn.gov)

❌ **Cloud Dependency**
- Azure Blob Storage (hardcoded)
- Not portable to AWS, GCP, or on-premises

---

## Transformation Goals

### Primary Objectives

1. **Multi-State Capability**
   - Any state can deploy with their own counties/regions
   - Configurable programs and document types
   - State-specific business rules

2. **Cloud Agnostic**
   - Support AWS, Azure, GCP, and on-premises
   - Abstracted storage (S3, Blob, GCS, MinIO, local)
   - Database provider flexibility (PostgreSQL on any cloud)

3. **Integration Flexibility**
   - Plugin architecture for document submission
   - Support SOAP, REST, SFTP, and email
   - State-specific adapters as needed

4. **Reduced Deployment Time**
   - From months → weeks for new states
   - Self-service configuration via admin UI
   - Comprehensive documentation and examples

5. **Open Source**
   - Public repository with clear governance
   - Active community support
   - State-contributed adapters and features

---

## Recommended Approach

### 8-Phase Implementation Plan

| Phase | Focus | Duration | Key Deliverables |
|-------|-------|----------|------------------|
| **1** | Extract MN-specific logic | 4-6 weeks | Configuration service, regions YAML |
| **2** | Integration adapters | 6-8 weeks | SOAP, REST, SFTP, email adapters |
| **3** | Database multi-tenancy | 3-4 weeks | Tenant tables, MN migration |
| **4** | Pilot state deployment | 6-8 weeks | Second state live in production |
| **5** | Business rules engine | 4-6 weeks | Externalized eligibility rules |
| **6** | Admin UI | 10-12 weeks | Self-service configuration portal |
| **7** | Documentation | 4-6 weeks | Setup guides, API docs, examples |
| **8** | Testing (ongoing) | Continuous | Multi-tenant test suite |

**Total Timeline:** 6-8 months with parallel work streams

### Critical Success Factors

1. **Start Small: Proof of Concept (Week 1-4)**
   - Extract County enum to configuration
   - Validate approach with minimal risk
   - Fast feedback before major investment

2. **Pilot State Selection (Month 3-4)**
   - Choose small/medium state
   - Simpler integration (email or SFTP, not complex SOAP)
   - Real-world validation before scaling

3. **Cloud Abstraction Early (Month 2)**
   - Storage abstraction in Phase 2
   - Enables states to choose their cloud
   - De-risks cloud lock-in

4. **Minnesota Backwards Compatibility**
   - Zero disruption to current users
   - Comprehensive regression testing
   - Feature flags for gradual rollout

---

## Resource Requirements

### Team Composition

**Months 1-4 (Foundation):**
- 1 Senior Backend Engineer (80%) - Architecture, core refactoring
- 1 Backend Engineer (80%) - Implementation, testing
- 0.5 DevOps Engineer - CI/CD, multi-tenant testing
- 0.5 Product Manager - Stakeholder management

**Months 5-8 (Pilot & UI):**
- Add: 1 Frontend Engineer (80%) - Admin UI
- Add: 1 QA Engineer (50%) - End-to-end testing
- Add: 1 State Partnership Manager (50%) - Pilot relationship

**Months 9-12 (Scale):**
- Add: 1 Technical Writer (50%) - Documentation
- Add: 1 Community Manager (25%) - Forums, support

### Budget Estimate

| Phase | Duration | Cost |
|-------|----------|------|
| Phase 1-3 (Foundation) | 4 months | $200-250K |
| Phase 4 (Pilot) | 2 months | $100-125K |
| Phase 5 (Admin UI) | 3 months | $150-200K |
| Phase 6 (Documentation) | 3 months | $75-100K |
| **Total** | **12 months** | **$525-675K** |

---

## Business Value

### For States

**Reduced Cost**
- Avoid custom development ($500K-2M per state)
- Shared maintenance and updates
- Open-source licensing (no vendor fees)

**Faster Deployment**
- 2-4 weeks to configure vs 6-12 months to build
- Pre-built integrations for common patterns
- Tested, production-ready platform

**Modern User Experience**
- Mobile-friendly, accessible
- Multi-language support
- Document upload and status tracking

**Flexibility**
- Choose your cloud provider
- Customize for state-specific programs
- Maintain control of infrastructure

### For the Ecosystem

**Open Source Community**
- States contribute back improvements
- Shared adapter library (SOAP, REST, SFTP patterns)
- Reduced duplication across states

**Code for America Impact**
- Demonstrate scalable civic tech model
- Help more residents access benefits
- Establish best practices for benefits applications

---

## Risk Assessment

### High Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Minnesota breaks during refactoring** | Critical | Comprehensive regression tests, feature flags, frequent staging validation |
| **Pilot state integration issues** | High | Choose state with simple integration (email/SFTP), build SFTP adapter early |
| **Other states have unique requirements** | Medium | Flexible config (JSONB), plugin architecture, good documentation |

### Medium Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Performance with multi-tenancy** | Medium | Configuration caching, query optimization, load testing |
| **States can't self-configure** | Medium | Admin UI, excellent docs, onboarding support |
| **Timeline slips** | Medium | Phased approach, MVP focus, parallel work streams |

### Low Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Cloud provider compatibility** | Low | Abstraction layer, test on multiple clouds |
| **Open source governance** | Low | Clear contribution guidelines, steering committee |

---

## Success Metrics

### Technical Metrics (Year 1)

- ✅ Minnesota 100% backwards compatible
- ✅ Second state deployed in <2 weeks of configuration
- ✅ <100ms latency added for tenant config lookup
- ✅ All integration tests passing for multi-tenant scenarios
- ✅ Support for 3+ cloud providers (AWS, Azure, GCP/on-prem)

### Adoption Metrics

- 🎯 **Year 1:** 3+ states using SHIBA
- 🎯 **Year 2:** 10+ states
- 🎯 **Year 3:** 20+ states

### Cost Metrics

- 💰 Deployment time: **Months → Weeks** (10-20x faster)
- 💰 Development cost: **$1.5M → $100K** per state (15x cheaper)
- 💰 Maintenance cost: **Shared** (vs individual per state)

### Community Metrics

- 👥 5+ external code contributors
- 👥 Active forum/Slack with 50+ members
- 👥 10+ state-specific adapters in community library

---

## Decision Points

### Month 1: Continue or Pivot?

**After POC (Priority 1):**
- ✅ If county extraction successful → Proceed with full Phase 1
- ⚠️ If too complex/risky → Revisit approach

### Month 4: Pilot Ready?

**After Phases 1-3:**
- ✅ If architecture solid → Begin pilot state onboarding
- ⚠️ If gaps found → Address before pilot

### Month 6: Scale or Refine?

**After Pilot:**
- ✅ If pilot successful → Build admin UI, scale to more states
- ⚠️ If pilot struggled → Refine based on learnings, delay scaling

---

## Recommended Next Steps

### Immediate (Next 2-4 Weeks)

1. ✅ **Review Discovery** - Validate findings with stakeholders
2. ✅ **Secure Budget** - Commit resources for 6-8 month project
3. ✅ **Identify Pilot State** - Start conversations with potential partners
4. ✅ **Start POC** - Extract County enum to configuration (low risk, high learning)

### Short Term (Months 2-4)

5. Complete Phase 1 (configuration extraction)
6. Implement Phase 2 (integration adapters)
7. Build Phase 3 (multi-tenancy database)
8. **Key Milestone:** Minnesota running on new architecture

### Medium Term (Months 5-8)

9. Onboard pilot state
10. Deploy pilot to production
11. Begin admin UI development
12. **Key Milestone:** Pilot state live and successful

### Long Term (Months 9-12)

13. Complete admin UI
14. Comprehensive documentation
15. Open source release
16. **Key Milestone:** 3+ states using SHIBA

---

## Why This Matters

### The Problem

States spend **$500K-2M+ and 6-18 months** building custom benefits applications. Many states still rely on outdated, inaccessible systems that frustrate applicants and staff.

### The Opportunity

A modern, open-source, configurable platform could:
- Help **50 states** modernize their benefits systems
- Reach **millions of residents** applying for benefits
- Save **hundreds of millions** in taxpayer dollars
- Improve **application completion rates** by 10-30%

### The SHIBA Advantage

SHIBA is already **production-proven** in Minnesota with:
- Thousands of applications processed
- High accessibility standards
- Modern tech stack
- Active maintenance and support

**We're 70% there.** This transformation makes it reusable for all states.

---

## Conclusion

SHIBA has a **solid foundation** and is **production-ready**. The transformation to multi-state, cloud-agnostic is:

✅ **Achievable** - Clear path with 8 phases
✅ **De-risked** - POC first, pilot before scale
✅ **Cost-effective** - $525-675K over 12 months
✅ **High-impact** - Enable 50 states to modernize
✅ **Incremental** - Minnesota keeps working throughout

### Recommended Decision

✅ **Approve** Phase 1 POC (4-6 weeks, ~$50K)
- Low risk, high learning
- Validates entire approach
- Easy go/no-go decision point

If POC succeeds → Approve full project.
If POC struggles → Minimal investment, early learning.

---

## Contact & Next Steps

**For questions about this discovery:**
- Review full documentation: `/DISCOVERY` folder
- Start with: `00-README.md` for navigation
- Technical details: `ARCHITECTURE-MERMAID.md`
- Implementation plan: `07-MULTI-STATE-ADAPTATION-PLAN.md`
- Cloud strategy: `09-CLOUD-PROVIDER-ABSTRACTION.md`

**Ready to proceed?**
1. Schedule stakeholder review meeting
2. Identify pilot state partner
3. Assign team members
4. Kick off POC (Week 1)

---

**Last Updated:** October 28, 2025
**Discovery Version:** 1.0
**Prepared By:** Technical Discovery Team

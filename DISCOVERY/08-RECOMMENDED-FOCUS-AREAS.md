# Recommended Focus Areas

Based on the comprehensive discovery analysis, here are my recommendations for where to focus next, prioritized by impact and feasibility.

---

## Priority 1: Proof of Concept - Configuration Extraction (IMMEDIATE)

### Why This First?
- **De-risks** the entire multi-state transformation
- **Validates** the configuration abstraction approach
- **Builds confidence** with stakeholders
- **Low risk** - doesn't change core functionality
- **Fast feedback** - 2-4 weeks to completion

### What to Build

**Goal:** Extract Minnesota's 87 counties from hardcoded enum to YAML configuration

**Steps:**
1. Create `Region` entity class
2. Create YAML configuration loader
3. Replace `County` enum references with `Region` lookups
4. Add database migration for `region` table
5. Write comprehensive tests

**Success Criteria:**
- Minnesota application works identically
- Easy to add a mock "California" with different counties
- <10ms performance impact
- All tests passing

**Deliverables:**
```java
// Before
County.HENNEPIN

// After
regionService.getRegion("HENNEPIN")
```

**Why This Matters:**
If this POC goes well, it proves the entire Phase 1 approach. If it's too complex or breaks things, we need to rethink the strategy before investing 6-8 months.

---

## Priority 2: Integration Adapter Pattern (HIGH VALUE)

### Why This Second?
- **Highest blocker** for multi-state adoption
- **Most state-specific** code (MNIT FileNet)
- **Enables** states with different integration methods
- **Clear interfaces** - well-understood problem

### What to Build

**Goal:** Abstract document submission so states can use SOAP, REST, SFTP, or email

**Steps:**
1. Define `DocumentSubmissionAdapter` interface
2. Refactor existing MNIT FileNet code into `MnitFilenetAdapter`
3. Build `EmailDocumentAdapter` (simplest alternative)
4. Build `SftpAdapter` (common state need)
5. Create adapter selection logic based on tenant config

**Success Criteria:**
- Minnesota uses MNIT adapter (no behavior change)
- Mock state uses email adapter successfully
- Easy to add new adapters (plugin architecture)
- Configuration-driven adapter selection

**Deliverables:**
```yaml
# Minnesota
integrations:
  document_submission:
    provider: "mnit_filenet"
    config:
      endpoint: "https://..."

# New State
integrations:
  document_submission:
    provider: "email"
    config:
      routing:
        HENNEPIN: "hennepin@state.example.gov"
```

**Why This Matters:**
Document submission is the #1 blocker for other states. Many states don't have SOAP APIs and rely on email or SFTP. This unlocks adoption.

---

## Priority 3: Database Multi-Tenancy (FOUNDATIONAL)

### Why This Third?
- **Foundation** for everything else
- **Required** before pilot state deployment
- **Not too complex** - well-understood pattern
- **Enables** parallel development of other features

### What to Build

**Goal:** Add tenant tables and migrate Minnesota to be a tenant

**Steps:**
1. Create `tenants`, `regions`, `programs` tables
2. Add `tenant_id` to `applications` table
3. Create Minnesota tenant record
4. Migrate existing Minnesota data
5. Update repositories to filter by tenant
6. Add tenant context service

**Success Criteria:**
- Minnesota data migrated successfully
- No performance degradation
- Easy to add second tenant
- Tenant isolation verified (security)

**Deliverables:**
```sql
-- Tenant table with Minnesota as first tenant
INSERT INTO tenants (id, state_code, name, timezone)
VALUES ('minnesota', 'MN', 'Minnesota', 'America/Chicago');

-- Applications now have tenant_id
ALTER TABLE applications ADD COLUMN tenant_id VARCHAR REFERENCES tenants(id);
```

**Why This Matters:**
This is the foundation for true multi-state support. Everything else builds on this.

---

## Priority 4: Pilot State Selection and Onboarding (VALIDATION)

### Why This Fourth?
- **Real-world validation** of architecture
- **Surface unknowns** early
- **Build process** before scaling to many states
- **Generate learnings** to improve approach

### What to Build

**Goal:** Fully deploy SHIBA for a second state (not Minnesota)

**Ideal Pilot State Characteristics:**
1. **Small-medium size** (20-50 counties, not 87 like Minnesota)
2. **Simpler integration** (prefer email/SFTP over complex SOAP)
3. **Fewer programs** (SNAP + 1-2 others, not 6)
4. **Technical capacity** (staff who can help troubleshoot)
5. **Commitment** (willing to be guinea pig)

**Steps:**
1. Identify and secure pilot state partner
2. Gather their requirements (programs, counties, integration method)
3. Configure SHIBA for pilot state
4. Deploy to staging environment
5. Conduct user acceptance testing
6. Go live with pilot
7. Document lessons learned

**Success Criteria:**
- Pilot state fully functional within 6-8 weeks of kickoff
- No changes needed to Minnesota deployment
- Clear gaps identified for improvement
- Pilot state satisfied with results

**Why This Matters:**
A successful pilot proves the multi-state vision and generates real feedback to improve before scaling.

---

## Priority 5: Admin UI for Configuration Management (SCALE)

### Why This Fifth?
- **Removes technical barrier** for states
- **Speeds up** state onboarding
- **Reduces errors** in configuration
- **Not urgent** until after pilot (can manually configure pilot state)

### What to Build

**Goal:** Web UI for non-technical users to configure tenants

**Phase 1 (MVP):**
- List/create/edit tenants
- Manage regions (counties)
- Configure programs
- Test integrations (health checks)

**Phase 2 (Enhanced):**
- User management (admins per state)
- Integration logs viewer
- Configuration validation
- Zip code mapping tool

**Phase 3 (Advanced):**
- Form builder (drag-and-drop)
- Business rules editor
- Template customization
- Multi-language management

**Technology:**
React Admin or similar (modern, flexible, customizable)

**Why This Matters:**
To scale to 10+ states, we need a way for states to self-configure without engineering support.

---

## Priority 6: Documentation and Open Source Prep (COMMUNITY)

### Why This Sixth?
- **Enables adoption** beyond pilot
- **Builds community** for long-term sustainability
- **Reduces support burden** with good docs
- **Not urgent** until architecture is stable (post-pilot)

### What to Build

**Deliverables:**
1. **README.md** - Clear project description, quick start
2. **SETUP.md** - Deployment guide for states
3. **CONFIGURATION.md** - All config options explained
4. **CONTRIBUTING.md** - How to contribute code
5. **ADAPTERS.md** - How to build custom integration adapters
6. **API-REFERENCE.md** - Complete API documentation
7. **FAQ.md** - Common questions from states
8. **GOVERNANCE.md** - Project governance model

**Also:**
- Video walkthroughs
- Sample configurations for different state types
- Troubleshooting guide
- Community forum setup (Discourse, GitHub Discussions)

**Why This Matters:**
Great documentation is the difference between 3 states using this vs 30 states using this.

---

## What NOT to Focus On (Yet)

### Low Priority / Defer

1. **Visual Form Builder** - Too complex, manual YAML editing is fine for now
2. **Advanced Analytics** - Mixpanel abstraction is low impact
3. **Mobile App** - Scope creep, mobile web works fine
4. **AI Features** - Not in scope for MVP multi-state support
5. **Payment Processing** - Not part of current SHIBA functionality
6. **Third-party Identity Verification** - Complex, defer until states request

---

## Staffing Recommendations

### Team Composition

**For Priorities 1-3 (Months 1-4):**
- 1 Senior Backend Engineer (80% time) - Architecture, refactoring
- 1 Backend Engineer (80% time) - Implementation, testing
- 0.5 DevOps Engineer - CI/CD, deployment automation
- 0.5 Product Manager - Requirements, stakeholder management

**For Priority 4 (Months 3-6, overlapping):**
- Add: 1 State Partnership Manager (50% time) - Pilot state relationship
- Add: 1 QA Engineer (50% time) - End-to-end testing with pilot

**For Priority 5 (Months 6-9):**
- Add: 1 Frontend Engineer (80% time) - Admin UI
- Continue: Backend engineers for API endpoints
- Add: 1 UX Designer (25% time) - Admin UI design

**For Priority 6 (Months 9-12):**
- Add: 1 Technical Writer (50% time) - Documentation
- Add: 1 Community Manager (25% time) - Forum, support

### Budget Estimate

**Rough Order of Magnitude (ROM):**
- Phase 1-3 (4 months): ~$200-250K (2 engineers, PM, DevOps)
- Phase 4 (2 months): ~$100-125K (add QA, partnership manager)
- Phase 5 (3 months): ~$150-200K (add frontend engineer)
- Phase 6 (3 months): ~$75-100K (documentation, community)

**Total: $525-675K over 12 months**

---

## Risk Mitigation

### Risk: Pilot State Integration Issues

**Mitigation:**
- Choose pilot state with email/SFTP (simpler than SOAP)
- Build SFTP adapter before pilot (Priority 2)
- Have fallback: email submission always works

### Risk: Minnesota Breaks During Refactoring

**Mitigation:**
- Comprehensive regression test suite before starting
- Feature flags for gradual rollout
- Maintain backwards compatibility
- Frequent testing against Minnesota staging environment

### Risk: Architecture Doesn't Scale to Other States

**Mitigation:**
- POC first (Priority 1)
- Pilot state early (Priority 4)
- Build flexibility into config system (JSONB for unknowns)
- Plugin architecture allows custom state extensions

### Risk: States Can't Self-Configure

**Mitigation:**
- Admin UI (Priority 5)
- Great documentation (Priority 6)
- Configuration validation and helpful error messages
- Onboarding support for first few states

---

## Quarterly Goals (Suggested)

### Q1 (Months 1-3)
- [ ] POC: County extraction complete and validated
- [ ] Phase 1: All Minnesota-specific logic extracted
- [ ] Phase 3: Multi-tenancy database schema implemented
- [ ] Minnesota migrated to tenant model, fully tested

### Q2 (Months 4-6)
- [ ] Phase 2: Integration adapters (SOAP, Email, SFTP) complete
- [ ] Pilot state selected and requirements gathered
- [ ] Pilot state configuration created
- [ ] Pilot state deployed to staging

### Q3 (Months 7-9)
- [ ] Pilot state live in production
- [ ] Lessons learned from pilot documented
- [ ] Phase 5: Business rules engine for expedited eligibility
- [ ] Phase 6: Admin UI MVP started

### Q4 (Months 10-12)
- [ ] Admin UI complete and deployed
- [ ] Phase 7: Documentation complete
- [ ] Open source repository public
- [ ] 2-3 additional states in onboarding pipeline

---

## Key Performance Indicators (KPIs)

### Development KPIs
- Code coverage >80% for multi-tenant code
- All integration tests passing
- <100ms latency for tenant config lookup
- Zero security vulnerabilities (Snyk, SonarQube)

### Adoption KPIs
- Time to deploy new state: <2 weeks (from weeks/months currently)
- States using SHIBA: 3+ by end of year 1, 10+ by end of year 2
- Application success rate: >95% (same as Minnesota baseline)

### Quality KPIs
- Uptime: 99.9% (same as Minnesota)
- Support tickets per state: <5/month (documentation quality)
- Community contributions: 5+ external contributors by end of year 1

---

## Decision Points

### Month 1 Decision: Continue or Pivot?
**After POC (Priority 1):**
- If successful → Proceed with full Phase 1
- If complex/risky → Revisit approach, consider simpler alternatives

### Month 4 Decision: Pilot State Ready?
**After Phases 1-3:**
- If architecture solid → Begin pilot state onboarding
- If gaps found → Address before pilot

### Month 6 Decision: Scale Up or Refine?
**After Pilot:**
- If pilot successful → Build admin UI, scale to more states
- If pilot struggled → Refine based on learnings, delay scaling

---

## Conclusion

**Start here:**
1. **Priority 1 POC** (2-4 weeks) - Proves the approach
2. **Priority 2 Adapters** (6-8 weeks) - Enables different integration methods
3. **Priority 3 Multi-tenancy** (3-4 weeks) - Foundation for everything

**Then validate:**
4. **Priority 4 Pilot State** (6-8 weeks) - Real-world test

**Then scale:**
5. **Priority 5 Admin UI** (10-12 weeks) - Enable self-service
6. **Priority 6 Documentation** (ongoing) - Enable community adoption

This approach is **incremental**, **de-risked**, and **delivers value** at each stage. Minnesota continues working throughout. The pilot state proves the model. The admin UI enables scale.

**Total timeline: 6-9 months to production-ready multi-state platform.**

---

**Next Action:** Review this discovery with stakeholders and make go/no-go decision on Priority 1 POC.

# Multi-State Adaptation Plan

## Executive Summary

SHIBA (State Hosted Integrated Benefits Application) is currently a Minnesota-specific benefits application system. This document outlines a comprehensive plan to transform it into a configurable, open-source platform that any state can deploy for their Income & Expense (IE&E) benefits programs.

**Current State:** Hardcoded for Minnesota with 87 counties, 11 tribal nations, 6 specific programs, and tight integration with Minnesota's MNIT FileNet system.

**Target State:** Configurable multi-state/multi-tenant platform with:
- Database-driven state configuration
- Pluggable integration adapters
- Flexible form engine
- Externalized business rules
- Admin UI for configuration management

---

## Phase 1: Extract and Externalize Minnesota-Specific Logic

**Duration:** 4-6 weeks
**Complexity:** Medium
**Risk:** Low (primarily refactoring)

### 1.1 Create Configuration Abstraction Layer

**Objective:** Replace hardcoded values with configuration lookups

**Tasks:**

#### A. Create Configuration Service
```java
@Service
public class TenantConfigurationService {
    private final TenantRepository tenantRepository;
    private final RegionRepository regionRepository;
    private final ProgramRepository programRepository;

    public TenantConfig getCurrentTenantConfig();
    public List<Region> getRegionsForTenant(String tenantId);
    public List<Program> getProgramsForTenant(String tenantId);
    public IntegrationConfig getIntegrationConfig(String tenantId);
}
```

**Files to modify:**
- Create: `/src/main/java/org/codeforamerica/shiba/config/tenant/TenantConfigurationService.java`
- Create: `/src/main/java/org/codeforamerica/shiba/config/tenant/TenantConfig.java`

#### B. Extract County Enum to Configuration
**Current:** `/src/main/java/org/codeforamerica/shiba/County.java` (87 hardcoded counties)

**Target:**
```yaml
# /src/main/resources/states/minnesota/regions.yaml
regions:
  - code: "HENNEPIN"
    name: "Hennepin County"
    type: "county"
    routing:
      email: "hennepin@state.mn.us"
      fax: "+15551234567"
```

**Migration steps:**
1. Create `Region` entity class
2. Create `RegionRepository`
3. Load regions from YAML on startup
4. Replace all `County` enum references with `Region` lookups
5. Update database: `ALTER TABLE applications RENAME COLUMN county TO region_code`

**Impact:**
- ~50 files reference `County` enum
- Main areas: routing, PDF generation, form logic

#### C. Extract Tribal Nations to Special Populations Config
**Current:** `/src/main/java/org/codeforamerica/shiba/TribalNation.java`

**Target:**
```yaml
special_populations:
  - id: "MILLE_LACS"
    type: "tribal_nation"
    name: "Mille Lacs Band of Ojibwe"
    overrides_region: true
    routing:
      email: "benefits@millelacsband.com"
      phone: "+12345678901"
```

#### D. Extract Program Definitions
**Current:** `/src/main/java/org/codeforamerica/shiba/application/parsers/ApplicationDataParser.java`

**Target:**
```yaml
programs:
  - code: "SNAP"
    name: "Supplemental Nutrition Assistance Program"
    federal: true
    enabled: true
  - code: "CERTAIN_POPS"
    name: "Community Action Funds"
    federal: false
    state_specific: true
    enabled: true
```

### 1.2 Externalize Routing Logic

**Current:** Hardcoded routing in:
- `/src/main/java/org/codeforamerica/shiba/output/MnitDocumentConsumer.java`
- `/src/main/java/org/codeforamerica/shiba/mnit/RoutingDestination.java`

**Target:** Configuration-driven routing

```yaml
routing:
  default_destination:
    type: "email"
    address: "intake@state.mn.us"

  region_routing:
    HENNEPIN:
      primary:
        type: "api"
        endpoint: "mnit_filenet"
      fallback:
        type: "email"
        address: "hennepin@state.mn.us"

  special_population_routing:
    MILLE_LACS:
      primary:
        type: "email"
        address: "benefits@millelacsband.com"
```

**Files to create:**
- `/src/main/java/org/codeforamerica/shiba/routing/RoutingService.java`
- `/src/main/java/org/codeforamerica/shiba/routing/RoutingRule.java`

### 1.3 Externalize Time Zone and Localization

**Current:** Hardcoded `America/Chicago` in `PageController.java:103`

**Target:**
```yaml
tenant:
  timezone: "America/Chicago"
  default_language: "en"
  supported_languages: ["en", "es", "hmn", "so"]
```

**Implementation:**
```java
@Component
public class TimeZoneProvider {
    public ZoneId getTenantTimeZone() {
        return ZoneId.of(tenantConfig.getTimezone());
    }
}
```

### 1.4 Externalize Admin Email List

**Current:** Hardcoded in `SecurityConfiguration.java`

**Target:** Database-driven admin users
```sql
CREATE TABLE admin_users (
    id VARCHAR PRIMARY KEY,
    email VARCHAR UNIQUE NOT NULL,
    tenant_id VARCHAR REFERENCES tenants(id),
    role VARCHAR,  -- ADMIN, COUNTY_WORKER, etc.
    created_at TIMESTAMP DEFAULT NOW()
);
```

---

## Phase 2: Create Integration Abstraction Layer

**Duration:** 6-8 weeks
**Complexity:** High
**Risk:** Medium (requires thorough testing)

### 2.1 Document Submission Abstraction

**Current:** Tightly coupled to MNIT FileNet SOAP API

**Target:** Plugin architecture supporting multiple backends

#### A. Define Core Interface
```java
public interface DocumentSubmissionAdapter {
    String getName();
    boolean supports(DocumentType documentType);
    SubmissionResult submit(SubmissionRequest request);
    SubmissionStatus checkStatus(String submissionId);
    boolean healthCheck();
}
```

#### B. Implement Adapters

**1. MNIT FileNet Adapter (Minnesota-specific)**
```java
@Component("mnitFilenetAdapter")
public class MnitFilenetAdapter implements DocumentSubmissionAdapter {
    // Existing FilenetWebServiceClient logic
}
```

**2. Generic SOAP Adapter**
```java
@Component("soapAdapter")
public class GenericSoapAdapter implements DocumentSubmissionAdapter {
    // Configurable WSDL, namespace, operations
    // XML mapping via configuration
}
```

**3. REST API Adapter**
```java
@Component("restApiAdapter")
public class RestApiAdapter implements DocumentSubmissionAdapter {
    // Configurable endpoints, auth (OAuth2, API key, Basic)
    // JSON mapping via configuration
}
```

**4. SFTP Adapter**
```java
@Component("sftpAdapter")
public class SftpAdapter implements DocumentSubmissionAdapter {
    // JSch or Apache Commons VFS
    // Configurable host, directory, file naming
}
```

**5. Email Adapter**
```java
@Component("emailAdapter")
public class EmailDocumentAdapter implements DocumentSubmissionAdapter {
    // Send documents as email attachments
    // Regional routing from config
}
```

#### C. Adapter Selection Logic
```java
@Service
public class DocumentSubmissionService {
    private final List<DocumentSubmissionAdapter> adapters;

    public SubmissionResult submitDocument(Application application, DocumentType docType) {
        // Load adapter name from tenant config
        String adapterName = tenantConfig.getDocumentSubmissionAdapter();
        DocumentSubmissionAdapter adapter = findAdapter(adapterName);

        // Submit
        return adapter.submit(buildRequest(application, docType));
    }
}
```

### 2.2 Email Service Abstraction

**Current:** Mailgun-specific

**Target:** Multiple provider support

```java
public interface EmailProvider {
    void sendEmail(EmailMessage message);
}

@Component
@ConditionalOnProperty(name = "integrations.email.provider", havingValue = "mailgun")
public class MailgunEmailProvider implements EmailProvider { }

@Component
@ConditionalOnProperty(name = "integrations.email.provider", havingValue = "sendgrid")
public class SendGridEmailProvider implements EmailProvider { }

@Component
@ConditionalOnProperty(name = "integrations.email.provider", havingValue = "smtp")
public class SmtpEmailProvider implements EmailProvider { }
```

### 2.3 Address Validation Abstraction

**Current:** SmartyStreets only

**Target:** Multiple providers + fallback to zip mapping

```java
public interface AddressValidationProvider {
    Optional<ValidatedAddress> validate(Address input);
}

// Implementations: SmartyStreets, USPS, Google, NoOp (zip mapping only)
```

### 2.4 Document Storage Abstraction

**Current:** Azure Blob Storage

**Target:** Multiple providers

```java
public interface DocumentStorageProvider {
    void store(String id, InputStream data, long size);
    InputStream retrieve(String id);
    void delete(String id);
}

// Implementations: Azure Blob, AWS S3, GCS, MinIO, Local FileSystem
```

---

## Phase 3: Database Multi-Tenancy Support

**Duration:** 3-4 weeks
**Complexity:** Medium
**Risk:** Medium (data migration)

### 3.1 Add Tenant Tables

```sql
-- Tenant/State configuration
CREATE TABLE tenants (
    id VARCHAR PRIMARY KEY,
    state_code VARCHAR(2) UNIQUE,
    name VARCHAR NOT NULL,
    timezone VARCHAR NOT NULL,
    default_language VARCHAR(2),
    config JSONB,  -- Flexible config storage
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Regions (counties, districts, parishes, etc.)
CREATE TABLE regions (
    id VARCHAR PRIMARY KEY,
    tenant_id VARCHAR REFERENCES tenants(id),
    code VARCHAR NOT NULL,
    name VARCHAR NOT NULL,
    type VARCHAR,  -- county, district, parish, tribal_nation
    routing_config JSONB,
    UNIQUE(tenant_id, code)
);

-- Programs per tenant
CREATE TABLE programs (
    id VARCHAR PRIMARY KEY,
    tenant_id VARCHAR REFERENCES tenants(id),
    code VARCHAR NOT NULL,
    name VARCHAR NOT NULL,
    enabled BOOLEAN DEFAULT true,
    federal BOOLEAN DEFAULT false,
    config JSONB,
    UNIQUE(tenant_id, code)
);

-- Document types per tenant
CREATE TABLE document_types (
    id VARCHAR PRIMARY KEY,
    tenant_id VARCHAR REFERENCES tenants(id),
    code VARCHAR NOT NULL,
    name VARCHAR NOT NULL,
    required BOOLEAN DEFAULT false,
    user_uploaded BOOLEAN DEFAULT false,
    generation_config JSONB,
    UNIQUE(tenant_id, code)
);

-- Integration configurations
CREATE TABLE integrations (
    id VARCHAR PRIMARY KEY,
    tenant_id VARCHAR REFERENCES tenants(id),
    integration_type VARCHAR NOT NULL,  -- document_submission, email, address_validation
    provider VARCHAR NOT NULL,  -- soap_api, rest_api, mailgun, etc.
    config JSONB NOT NULL,
    enabled BOOLEAN DEFAULT true,
    UNIQUE(tenant_id, integration_type)
);
```

### 3.2 Update Application Table

```sql
-- Add tenant reference
ALTER TABLE applications ADD COLUMN tenant_id VARCHAR REFERENCES tenants(id);

-- Rename county to region_code (more generic)
ALTER TABLE applications RENAME COLUMN county TO region_code;

-- Add indexes
CREATE INDEX applications_tenant_id_idx ON applications(tenant_id);
CREATE INDEX applications_region_code_idx ON applications(region_code);
```

### 3.3 Data Migration for Minnesota

```sql
-- Create Minnesota tenant
INSERT INTO tenants (id, state_code, name, timezone, default_language)
VALUES ('minnesota', 'MN', 'Minnesota', 'America/Chicago', 'en');

-- Migrate existing applications
UPDATE applications SET tenant_id = 'minnesota' WHERE tenant_id IS NULL;

-- Import Minnesota regions from existing County enum
INSERT INTO regions (id, tenant_id, code, name, type)
SELECT
    'mn-' || LOWER(code),
    'minnesota',
    code,
    name,
    'county'
FROM (
    -- 87 Minnesota counties
    VALUES
        ('HENNEPIN', 'Hennepin County'),
        ('RAMSEY', 'Ramsey County'),
        -- ... all 87 counties
) AS counties(code, name);
```

---

## Phase 4: Form Engine Configurability

**Duration:** 8-10 weeks
**Complexity:** High
**Risk:** High (core application logic)

### 4.1 Current Form System

**Current:** `pages-config.yaml` (3000+ lines) defines:
- Page order and navigation
- Conditional logic (which pages appear based on answers)
- Subworkflows (household members, jobs, income)
- Validation rules

**Challenge:** This file is Minnesota-specific with hardcoded:
- Program names
- Minnesota-specific questions (tribal enrollment, etc.)
- County selection logic

### 4.2 Make Form Config Tenant-Specific

**Structure:**
```
/src/main/resources/
└── tenants/
    ├── minnesota/
    │   ├── pages-config.yaml
    │   ├── validation-rules.yaml
    │   └── messages_en.properties
    ├── california/
    │   ├── pages-config.yaml
    │   └── ...
    └── default/
        └── pages-config.yaml  # Base template
```

### 4.3 Form Configuration Loading

```java
@Service
public class FormConfigurationService {
    public PagesConfiguration loadPagesConfig(String tenantId) {
        // Load base config
        PagesConfiguration base = loadYaml("tenants/default/pages-config.yaml");

        // Load tenant-specific config
        PagesConfiguration tenantConfig = loadYaml("tenants/" + tenantId + "/pages-config.yaml");

        // Merge (tenant overrides base)
        return merge(base, tenantConfig);
    }
}
```

### 4.4 Conditional Logic Abstraction

**Current:** Hardcoded Java classes for conditions

**Target:** Expression language (Spring EL or similar)

**Example:**
```yaml
pages:
  - name: "household_members"
    next:
      - condition: "hasProgram('SNAP') || hasProgram('CASH')"
        page: "household_list"
      - condition: "hasProgram('CCAP')"
        page: "child_care_provider"
      - default: "income_intro"
```

---

## Phase 5: Business Rules Externalization

**Duration:** 4-6 weeks
**Complexity:** High
**Risk:** High (eligibility calculations)

### 5.1 Current Eligibility Logic

**Files:**
- `/src/main/java/org/codeforamerica/shiba/application/parsers/ExpeditedEligibilityDecider.java`
- `/src/main/java/org/codeforamerica/shiba/application/parsers/CcapExpeditedEligibilityDecider.java`

**Problem:** Hardcoded thresholds and rules specific to Minnesota

### 5.2 Rules Engine Integration

**Option A: Drools**
```java
// Define rules in .drl files per state
// /src/main/resources/tenants/minnesota/rules/snap-expedited.drl

rule "SNAP Expedited - Very Low Income"
when
    Application(monthlyIncome < 150, liquidResources < 100)
then
    setExpeditedEligibility("SNAP", "ELIGIBLE");
end
```

**Option B: Easy Rules (Lightweight)**
```java
@Rule(name = "SNAP Expedited - Very Low Income")
public class SnapExpeditedRule {
    @Condition
    public boolean evaluate(Application app) {
        return app.getMonthlyIncome() < 150 && app.getLiquidResources() < 100;
    }

    @Action
    public void execute(Application app) {
        app.setExpeditedEligibility("SNAP", "ELIGIBLE");
    }
}
```

**Option C: Configuration-Based (Simple Rules)**
```yaml
eligibility_rules:
  snap_expedited:
    - name: "very_low_income"
      conditions:
        - field: "monthly_income"
          operator: "<"
          value: 150
        - field: "liquid_resources"
          operator: "<"
          value: 100
      result: "ELIGIBLE"
```

### 5.3 Implementation

```java
@Service
public class EligibilityService {
    private final RulesEngine rulesEngine;

    public ExpeditedEligibility determineEligibility(Application app, String program) {
        // Load rules for tenant and program
        List<Rule> rules = loadRules(app.getTenantId(), program);

        // Execute rules
        return rulesEngine.evaluate(app, rules);
    }
}
```

---

## Phase 6: Admin UI for Configuration Management

**Duration:** 10-12 weeks
**Complexity:** High
**Risk:** Low (new feature)

### 6.1 Admin Dashboard Requirements

**Features:**
1. **Tenant Management**
   - Create/edit tenants (states)
   - Configure timezone, language, branding

2. **Region Management**
   - Add/edit/delete regions (counties, districts)
   - Configure routing for each region
   - Zip code to region mapping

3. **Program Configuration**
   - Enable/disable programs per state
   - Configure program names and descriptions
   - Set eligibility rules (UI or upload rules files)

4. **Integration Management**
   - Configure document submission adapter
   - Test integrations (health checks)
   - View submission logs and failures

5. **Form Builder (Advanced)**
   - Visual form builder for creating pages
   - Drag-and-drop field placement
   - Conditional logic builder
   - (This is a major undertaking - Phase 7+)

### 6.2 Technology Options

**Option A: React Admin SPA**
```
/admin-ui/ (separate React app)
├── src/
│   ├── components/
│   │   ├── TenantList.tsx
│   │   ├── RegionManager.tsx
│   │   └── IntegrationConfig.tsx
│   └── api/
│       └── adminApi.ts
```

**Option B: Spring Boot Admin (Java-based)**
- Thymeleaf templates
- Server-side rendered
- Simpler to integrate

**Option C: Third-party CMS**
- Strapi, KeystoneJS for configuration management

### 6.3 Admin API Endpoints

```java
@RestController
@RequestMapping("/api/admin")
public class AdminApiController {

    @GetMapping("/tenants")
    public List<Tenant> listTenants();

    @PostMapping("/tenants")
    public Tenant createTenant(@RequestBody TenantRequest request);

    @PutMapping("/tenants/{id}")
    public Tenant updateTenant(@PathVariable String id, @RequestBody TenantRequest request);

    @GetMapping("/tenants/{id}/regions")
    public List<Region> listRegions(@PathVariable String id);

    @PostMapping("/tenants/{id}/regions")
    public Region createRegion(@PathVariable String id, @RequestBody RegionRequest request);

    @GetMapping("/tenants/{id}/programs")
    public List<Program> listPrograms(@PathVariable String id);

    @PostMapping("/tenants/{id}/integrations/test")
    public IntegrationTestResult testIntegration(@PathVariable String id, @RequestBody IntegrationTestRequest request);
}
```

---

## Phase 7: Documentation and Onboarding

**Duration:** 4-6 weeks
**Complexity:** Medium
**Risk:** Low

### 7.1 Technical Documentation

**Docs to create:**
1. **Setup Guide** - How to deploy SHIBA for a new state
2. **Configuration Reference** - All config options explained
3. **Integration Guide** - How to build custom adapters
4. **API Documentation** - OpenAPI/Swagger
5. **Database Schema Documentation** - ER diagrams
6. **Developer Guide** - How to contribute

### 7.2 State Onboarding Checklist

**Step-by-step guide for new states:**

```markdown
# SHIBA Deployment Guide for States

## Prerequisites
- [ ] PostgreSQL 11+ database
- [ ] Java 17+ runtime
- [ ] Document storage (Azure Blob, AWS S3, or local)
- [ ] Email service (Mailgun, SendGrid, or SMTP)
- [ ] SSL certificates (if applicable)

## Step 1: Create Tenant Configuration
- [ ] Choose state code (e.g., "CA" for California)
- [ ] Define regions (counties/districts)
- [ ] Map zip codes to regions
- [ ] Define programs offered

## Step 2: Configure Integrations
- [ ] Choose document submission method (API, SFTP, email)
- [ ] Set up credentials
- [ ] Test integration

## Step 3: Customize Forms
- [ ] Copy `default/pages-config.yaml` to `states/{state}/`
- [ ] Modify questions for state-specific programs
- [ ] Translate to supported languages

## Step 4: Configure Business Rules
- [ ] Define expedited eligibility rules
- [ ] Set income thresholds
- [ ] Configure validation rules

## Step 5: Deploy and Test
- [ ] Deploy application
- [ ] Run smoke tests
- [ ] Submit test application end-to-end
- [ ] Verify document delivery

## Step 6: Go Live
- [ ] User acceptance testing
- [ ] Staff training
- [ ] Launch!
```

### 7.3 Sample Configurations

Provide complete examples for:
- Small state (few counties, simple programs)
- Large state (many regions, multiple programs)
- State with tribal nations/special populations
- State using different integration methods (SFTP vs API)

---

## Phase 8: Testing and Quality Assurance

**Duration:** Ongoing
**Complexity:** High
**Risk:** High

### 8.1 Test Strategy

**Unit Tests**
- Configuration loading
- Adapter selection logic
- Business rules evaluation
- Form navigation

**Integration Tests**
- Mock external APIs (WireMock)
- Database operations
- End-to-end form submission

**Multi-Tenant Tests**
- Tenant isolation
- Configuration switching
- Parallel submissions from different tenants

**Compatibility Tests**
- Test with Minnesota configuration (backwards compatibility)
- Test with new states (forward compatibility)

### 8.2 Test Automation

```java
@SpringBootTest
@Sql("/test-data/minnesota-tenant.sql")
class MinnesotaTenantTest {

    @Test
    void shouldSubmitApplicationForHennepinCounty() {
        // Test full flow with Minnesota config
    }
}

@SpringBootTest
@Sql("/test-data/california-tenant.sql")
class CaliforniaTenantTest {

    @Test
    void shouldSubmitApplicationForLosAngelesCounty() {
        // Test full flow with California config
    }
}
```

---

## Implementation Roadmap

### Timeline Summary

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: Extract MN-specific logic | 4-6 weeks | None |
| Phase 2: Integration abstraction | 6-8 weeks | Phase 1 |
| Phase 3: Database multi-tenancy | 3-4 weeks | Phase 1 |
| Phase 4: Form engine configurability | 8-10 weeks | Phase 1, 3 |
| Phase 5: Business rules externalization | 4-6 weeks | Phase 1, 3 |
| Phase 6: Admin UI | 10-12 weeks | Phase 2, 3 |
| Phase 7: Documentation | 4-6 weeks | All phases |
| Phase 8: Testing (ongoing) | Continuous | All phases |

**Total Estimated Time: 39-52 weeks (9-12 months)**

### Parallel Work Streams

Some phases can be parallelized:
- **Stream 1:** Phases 1 → 2 → 6
- **Stream 2:** Phases 1 → 3 → 4 → 5
- **Stream 3:** Phase 7 (documentation) throughout
- **Stream 4:** Phase 8 (testing) throughout

With parallel work: **6-8 months**

---

## Risks and Mitigation

### Risk 1: Breaking Changes for Minnesota
**Impact:** High
**Probability:** Medium
**Mitigation:**
- Maintain backwards compatibility
- Extensive regression testing
- Feature flags for gradual rollout
- Keep Minnesota as reference implementation

### Risk 2: Complex State-Specific Requirements
**Impact:** Medium
**Probability:** High
**Mitigation:**
- Flexible configuration system (JSONB for unknown requirements)
- Plugin architecture for custom logic
- Strong documentation and examples
- Community support for state-specific extensions

### Risk 3: Performance with Multi-Tenancy
**Impact:** Medium
**Probability:** Low
**Mitigation:**
- Configuration caching
- Database query optimization
- Load testing with multiple tenants
- Horizontal scaling support

### Risk 4: Integration Failures
**Impact:** High
**Probability:** Medium
**Mitigation:**
- Robust retry logic (already exists)
- Multiple fallback channels (email, SFTP)
- Comprehensive health checks
- Alerting and monitoring

---

## Success Metrics

### Technical Metrics
- [ ] Minnesota continues to work without issues (100% backwards compatibility)
- [ ] Second state successfully deployed within 2 weeks of configuration
- [ ] All integration tests passing
- [ ] <100ms added latency for tenant config lookup

### Business Metrics
- [ ] 3+ states using SHIBA within 12 months of release
- [ ] Reduce time-to-deploy for new state from months to weeks
- [ ] 90%+ applicant satisfaction (current Minnesota baseline)

### Community Metrics
- [ ] Open source repository with clear documentation
- [ ] 5+ external contributors
- [ ] Active community forum/Slack channel
- [ ] State-specific plugins/adapters shared by community

---

## Next Steps (Immediate Actions)

### Week 1-2: Planning and Setup
1. **Create project board** with all phases and tasks
2. **Set up CI/CD pipeline** for multi-tenant testing
3. **Create feature branch** for Phase 1 work
4. **Stakeholder alignment** - present plan to Minnesota team and potential other states

### Week 3-4: Begin Phase 1
1. **Create TenantConfigurationService** skeleton
2. **Extract County enum to Region entity**
3. **Set up test fixtures** for Minnesota and mock second state
4. **Write migration scripts** for existing Minnesota data

### Month 2-3: Continue Phase 1 and 3
1. Complete configuration extraction
2. Add tenant tables to database
3. Migrate Minnesota to use new tenant system
4. Comprehensive testing

---

## Appendix: Key Files to Modify

### High Priority (Core Logic)
1. `/src/main/java/org/codeforamerica/shiba/County.java` - Extract to config
2. `/src/main/java/org/codeforamerica/shiba/TribalNation.java` - Extract to config
3. `/src/main/java/org/codeforamerica/shiba/mnit/FilenetWebServiceClient.java` - Wrap in adapter
4. `/src/main/java/org/codeforamerica/shiba/pages/PageController.java` - Use tenant timezone
5. `/src/main/java/org/codeforamerica/shiba/configurations/SecurityConfiguration.java` - Database-driven admin users
6. `/src/main/java/org/codeforamerica/shiba/output/MnitDocumentConsumer.java` - Use adapter pattern
7. `/src/main/resources/pages-config.yaml` - Make tenant-specific

### Medium Priority (Features)
8. `/src/main/java/org/codeforamerica/shiba/application/parsers/ExpeditedEligibilityDecider.java` - Externalize rules
9. `/src/main/java/org/codeforamerica/shiba/pages/emails/MailGunEmailClient.java` - Abstract email provider
10. `/src/main/java/org/codeforamerica/shiba/documents/AzureDocumentRepository.java` - Abstract storage

### Low Priority (Nice to Have)
11. `/src/main/java/org/codeforamerica/shiba/pages/enrichment/smartystreets/SmartyStreetClient.java` - Abstract address validation
12. `/src/main/java/org/codeforamerica/shiba/pages/events/MixpanelInteractionTracker.java` - Abstract analytics

---

## Conclusion

Transforming SHIBA into a multi-state platform is a significant but achievable undertaking. The phased approach allows for incremental progress while maintaining stability for Minnesota. The plugin architecture and configuration-driven design will enable other states to adopt SHIBA with minimal custom development.

**Recommended Approach:**
1. Start with Phase 1 to prove out the configuration abstraction
2. Build Phase 3 database multi-tenancy in parallel
3. Implement one non-Minnesota state as a pilot (e.g., a smaller state with simpler requirements)
4. Use pilot learnings to refine approach before broader rollout
5. Build admin UI (Phase 6) based on real configuration pain points from pilot

This approach de-risks the project while delivering value incrementally.

# SHIBA Architecture Diagrams

## Current Architecture (Minnesota-Specific)

```
┌─────────────────────────────────────────────────────────────────┐
│                         User (Citizen)                           │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTPS
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Spring Boot Application                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              PageController (Thymeleaf)                   │  │
│  │  - Form navigation                                        │  │
│  │  - Session management (JDBC session store)                │  │
│  │  - File uploads                                           │  │
│  └──────────────────────────┬───────────────────────────────┘  │
│                             │                                    │
│  ┌──────────────────────────▼───────────────────────────────┐  │
│  │         ApplicationSubmittedEvent (Async)                 │  │
│  └──┬──────────────┬──────────────┬──────────────┬──────────┘  │
│     │              │              │              │               │
│     ▼              ▼              ▼              ▼               │
│  ┌──────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐        │
│  │ PDF  │   │  Email   │   │  MNIT    │   │Mixpanel  │        │
│  │ Gen  │   │ Service  │   │FileNet   │   │Analytics │        │
│  └──┬───┘   └────┬─────┘   └────┬─────┘   └────┬─────┘        │
└─────┼────────────┼──────────────┼──────────────┼──────────────┘
      │            │              │              │
      │            ▼              ▼              │
      │    ┌──────────────┐  ┌──────────────┐  │
      │    │   Mailgun    │  │ MNIT FileNet │  │
      │    │   (Email)    │  │   (SOAP)     │  │
      │    └──────────────┘  └──────────────┘  │
      │                                         │
      ▼                                         ▼
  ┌──────────────┐                      ┌──────────────┐
  │ Azure Blob   │                      │  Mixpanel    │
  │   Storage    │                      │   (Cloud)    │
  └──────────────┘                      └──────────────┘

      ▼
  ┌──────────────┐
  │ PostgreSQL   │
  │  - applications (JSONB)
  │  - application_status
  │  - spring_session
  └──────────────┘

HARDCODED:
- 87 Minnesota Counties (Enum)
- 11 Tribal Nations (Enum)
- MNIT FileNet SOAP endpoint
- Mailgun domain (mail.mnbenefits.mn.gov)
- America/Chicago timezone
```

---

## Target Architecture (Multi-State)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Users (Multiple States)                       │
└────────────────┬─────────────────┬──────────────────────────────┘
                 │                 │
      Minnesota  │                 │  California (example)
                 │                 │
                 ▼                 ▼
┌─────────────────────────────────────────────────────────────────┐
│              Spring Boot Application (Multi-Tenant)              │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │           Tenant Context Service                          │  │
│  │  - Detects tenant from domain/subdomain                   │  │
│  │  - Loads tenant configuration                             │  │
│  │  - Sets timezone, language, branding                      │  │
│  └─────────────────────────┬─────────────────────────────────┘  │
│                            │                                     │
│  ┌─────────────────────────▼─────────────────────────────────┐  │
│  │         PageController (Thymeleaf)                        │  │
│  │  - Tenant-specific form configuration                     │  │
│  │  - Dynamic page navigation                                │  │
│  └─────────────────────────┬─────────────────────────────────┘  │
│                            │                                     │
│  ┌─────────────────────────▼─────────────────────────────────┐  │
│  │      ApplicationSubmittedEvent (Async)                    │  │
│  └──┬─────────────┬──────────────┬──────────────┬────────────┘  │
│     │             │              │              │                │
│     ▼             ▼              ▼              ▼                │
│  ┌──────┐   ┌──────────┐   ┌──────────────────────────────┐   │
│  │ PDF  │   │  Email   │   │  Document Submission Service  │   │
│  │ Gen  │   │ Service  │   │  - Adapter pattern            │   │
│  │      │   │ (Multi-  │   │  - Tenant config selects      │   │
│  │      │   │ Provider)│   │    adapter                    │   │
│  └──┬───┘   └────┬─────┘   └─────────┬────────────────────┘   │
└─────┼────────────┼───────────────────┼──────────────────────────┘
      │            │                   │
      │            ▼                   ▼
      │    ┌──────────────┐    ┌──────────────────────────────┐
      │    │Email Provider│    │  Submission Adapters         │
      │    │   Factory    │    │  ┌────────────────────────┐  │
      │    │  - Mailgun   │    │  │ MNIT FileNet Adapter   │  │
      │    │  - SendGrid  │    │  │   (Minnesota)          │  │
      │    │  - SMTP      │    │  ├────────────────────────┤  │
      │    └──────────────┘    │  │ SOAP Adapter (Generic) │  │
      │                        │  ├────────────────────────┤  │
      │                        │  │ REST API Adapter       │  │
      │                        │  ├────────────────────────┤  │
      │                        │  │ SFTP Adapter           │  │
      │                        │  ├────────────────────────┤  │
      │                        │  │ Email Adapter          │  │
      │                        │  └────────────────────────┘  │
      │                        └──────────────────────────────┘
      │
      ▼
  ┌──────────────────┐
  │ Storage Provider │
  │    Factory       │
  │  - Azure Blob    │
  │  - AWS S3        │
  │  - Local FS      │
  └──────────────────┘

      ▼
  ┌──────────────────────────────────────────────────────────────┐
  │                    PostgreSQL (Multi-Tenant)                  │
  │  ┌────────────────────────────────────────────────────────┐  │
  │  │ Core Tables                                            │  │
  │  │  - applications (tenant_id, region_code)               │  │
  │  │  - application_status                                  │  │
  │  ├────────────────────────────────────────────────────────┤  │
  │  │ Configuration Tables                                   │  │
  │  │  - tenants (state_code, name, config)                  │  │
  │  │  - regions (tenant_id, code, routing_config)           │  │
  │  │  - programs (tenant_id, code, name)                    │  │
  │  │  - document_types (tenant_id, code)                    │  │
  │  │  - integrations (tenant_id, provider, config)          │  │
  │  └────────────────────────────────────────────────────────┘  │
  └──────────────────────────────────────────────────────────────┘
```

---

## Multi-Tenant Request Flow

```
1. User Request
   https://mn.benefits.gov/pages/personalInfo
        │
        ▼
2. Tenant Detection Middleware
   ┌─────────────────────────────────────┐
   │ Extract from:                       │
   │  - Subdomain (mn.benefits.gov)      │
   │  - OR custom domain mapping         │
   │  - OR session/cookie                │
   └──────────────┬──────────────────────┘
                  │
                  ▼
3. Load Tenant Config
   ┌─────────────────────────────────────┐
   │ TenantConfigService.load("mn")      │
   │  - Timezone: America/Chicago        │
   │  - Regions: 87 counties             │
   │  - Programs: SNAP, CCAP, CASH, etc. │
   │  - Integrations: MNIT FileNet       │
   └──────────────┬──────────────────────┘
                  │
                  ▼
4. Set Request Context
   ┌─────────────────────────────────────┐
   │ ThreadLocal<TenantContext>          │
   │  - tenant_id: "minnesota"           │
   │  - state_code: "MN"                 │
   │  - timezone: ZoneId                 │
   └──────────────┬──────────────────────┘
                  │
                  ▼
5. Process Request
   ┌─────────────────────────────────────┐
   │ PageController.showPage()           │
   │  - Load page config for tenant      │
   │  - Render with tenant branding      │
   │  - Use tenant timezone              │
   └──────────────┬──────────────────────┘
                  │
                  ▼
6. Database Query (Tenant-Filtered)
   ┌─────────────────────────────────────┐
   │ SELECT * FROM applications          │
   │ WHERE tenant_id = 'minnesota'       │
   │ AND id = ?                          │
   └─────────────────────────────────────┘
```

---

## Adapter Pattern for Document Submission

```
                    Application Submitted
                            │
                            ▼
                ┌──────────────────────────┐
                │ DocumentSubmissionService│
                │  - Gets tenant config    │
                │  - Selects adapter       │
                └───────────┬──────────────┘
                            │
            ┌───────────────┼───────────────────┐
            │               │                   │
            ▼               ▼                   ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │ MNIT FileNet │ │  REST API    │ │    SFTP      │
    │   Adapter    │ │   Adapter    │ │   Adapter    │
    └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
           │                │                │
           ▼                ▼                ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │ SOAP Client  │ │ HTTP Client  │ │ SFTP Client  │
    │ (WebClient)  │ │ (WebClient)  │ │   (JSch)     │
    └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
           │                │                │
           ▼                ▼                ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │   MNIT       │ │  State API   │ │ State SFTP   │
    │  FileNet     │ │  Endpoint    │ │   Server     │
    └──────────────┘ └──────────────┘ └──────────────┘

Each adapter implements:
  - submit(request) → SubmissionResult
  - checkStatus(id) → SubmissionStatus
  - healthCheck() → boolean
```

---

## Configuration Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    Configuration Hierarchy                   │
├─────────────────────────────────────────────────────────────┤
│ Layer 1: Default (application.yaml)                         │
│  - Database connection                                       │
│  - Server port                                               │
│  - Session timeout                                           │
│  - Security settings                                         │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: Tenant Config (Database: tenants table)            │
│  - state_code: "MN"                                          │
│  - timezone: "America/Chicago"                               │
│  - default_language: "en"                                    │
│  - branding: { logo, colors }                                │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: Regions (Database: regions table)                  │
│  - HENNEPIN → routing: { email, fax }                        │
│  - RAMSEY → routing: { email }                               │
│  - ... 87 total for MN                                       │
├─────────────────────────────────────────────────────────────┤
│ Layer 4: Programs (Database: programs table)                │
│  - SNAP (enabled, federal)                                   │
│  - CCAP (enabled, federal)                                   │
│  - CERTAIN_POPS (enabled, state-specific)                    │
├─────────────────────────────────────────────────────────────┤
│ Layer 5: Integrations (Database: integrations table)        │
│  - document_submission:                                      │
│    provider: "mnit_filenet"                                  │
│    config: { endpoint, username, password }                  │
│  - email_service:                                            │
│    provider: "mailgun"                                       │
│    config: { domain, api_key }                               │
├─────────────────────────────────────────────────────────────┤
│ Layer 6: Form Structure (YAML files per tenant)             │
│  /tenants/minnesota/pages-config.yaml                        │
│  - Page definitions                                          │
│  - Conditional navigation                                    │
│  - Validation rules                                          │
├─────────────────────────────────────────────────────────────┤
│ Layer 7: Business Rules (Rules engine files)                │
│  /tenants/minnesota/rules/snap-expedited.drl                 │
│  - Eligibility thresholds                                    │
│  - Calculation logic                                         │
└─────────────────────────────────────────────────────────────┘

   Overrides flow: Layer 7 > Layer 6 > ... > Layer 1
```

---

## Data Flow: Application Submission

```
┌─────────┐
│  User   │
│ (Forms) │
└────┬────┘
     │
     │ POST /pages/{page}
     ▼
┌─────────────────────┐
│   PageController    │
│  - Validate input   │
│  - Store in session │
└─────────┬───────────┘
          │
          │ (repeats for each page)
          ▼
     ┌─────────────┐
     │   Session   │───────────┐
     │ (JDBC store)│           │
     └─────────────┘           │
          │                    │
          │ POST /submit       │
          ▼                    │
┌──────────────────────┐       │
│ PageController       │       │
│  .submit()           │       │
│  - Load from session │◄──────┘
│  - Create Application│
│  - Save to database  │
│  - Publish event     │
└──────────┬───────────┘
           │
           │ ApplicationSubmittedEvent
           ▼
┌───────────────────────────────────────────┐
│     ApplicationSubmittedListener          │
│  (Async - @EventListener)                 │
└─┬─────────────────────┬──────────────┬────┘
  │                     │              │
  ▼                     ▼              ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Generate PDFs│  │  Send Email  │  │  Submit to   │
│  - CAF       │  │ Confirmation │  │ State System │
│  - CCAP      │  │              │  │  (Adapter)   │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Azure Blob   │  │   Mailgun    │  │ MNIT FileNet │
│  Storage     │  │              │  │   (SOAP)     │
└──────────────┘  └──────────────┘  └──────┬───────┘
                                           │
                                           ▼
                                    ┌──────────────┐
                                    │Update status │
                                    │ in database  │
                                    │  - SENDING   │
                                    │  - DELIVERED │
                                    │  - FAILED    │
                                    └──────────────┘
```

---

## Admin UI Architecture (Proposed)

```
┌─────────────────────────────────────────────────────────────┐
│                      Admin Dashboard                         │
│                     (React Admin SPA)                        │
├─────────────────────────────────────────────────────────────┤
│  Tenant Management  │  Region Config  │  Integration Setup  │
│  ┌──────────────┐   │  ┌───────────┐  │  ┌──────────────┐  │
│  │ - List       │   │  │ - Add     │  │  │ - Test       │  │
│  │ - Create     │   │  │ - Edit    │  │  │ - Configure  │  │
│  │ - Edit       │   │  │ - Delete  │  │  │ - Health     │  │
│  │ - Delete     │   │  │ - Zip Map │  │  │ - Logs       │  │
│  └──────────────┘   │  └───────────┘  │  └──────────────┘  │
└──────────┬──────────────────┬──────────────────┬────────────┘
           │                  │                  │
           │   REST API       │                  │
           ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│            Admin API Controller (Spring Boot)                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ POST /api/   │  │ GET /api/    │  │ POST /api/   │      │
│  │ admin/       │  │ admin/       │  │ admin/       │      │
│  │ tenants      │  │ tenants/{id} │  │ integrations │      │
│  │              │  │ /regions     │  │ /test        │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
                  ┌────────────────┐
                  │   PostgreSQL   │
                  │  - tenants     │
                  │  - regions     │
                  │  - programs    │
                  │  - integrations│
                  └────────────────┘
```

---

## Deployment Options

### Option 1: Multi-Tenant SaaS (Shared Infrastructure)

```
                    ┌────────────────┐
                    │  Load Balancer │
                    └────────┬───────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ App Instance │     │ App Instance │     │ App Instance │
│      1       │     │      2       │     │      3       │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │
       └────────────────────┼────────────────────┘
                            │
                            ▼
                   ┌────────────────┐
                   │   PostgreSQL   │
                   │   (Shared)     │
                   │  - tenant: MN  │
                   │  - tenant: CA  │
                   │  - tenant: TX  │
                   └────────────────┘

Pros: Cost-effective, easy updates, shared maintenance
Cons: Tenant isolation concerns, state data sovereignty issues
```

### Option 2: Isolated Instances (Per-State Deployment)

```
Minnesota:                      California:
┌──────────────┐                ┌──────────────┐
│ App Instance │                │ App Instance │
│  (MN only)   │                │  (CA only)   │
└──────┬───────┘                └──────┬───────┘
       │                               │
       ▼                               ▼
┌──────────────┐                ┌──────────────┐
│ PostgreSQL   │                │ PostgreSQL   │
│  (MN data)   │                │  (CA data)   │
└──────────────┘                └──────────────┘

Pros: Complete isolation, state controls infrastructure
Cons: Higher cost, each state manages updates
```

### Option 3: Hybrid (Regional Shared)

```
        Midwest Region                West Coast Region
┌──────────────────────────┐    ┌──────────────────────────┐
│ MN, WI, IA, etc.         │    │ CA, OR, WA, etc.         │
│  ┌────────────────┐      │    │  ┌────────────────┐      │
│  │ App Instances  │      │    │  │ App Instances  │      │
│  └───────┬────────┘      │    │  └───────┬────────┘      │
│          │               │    │          │               │
│          ▼               │    │          ▼               │
│  ┌────────────────┐      │    │  ┌────────────────┐      │
│  │  PostgreSQL    │      │    │  │  PostgreSQL    │      │
│  │  (Multi-tenant)│      │    │  │  (Multi-tenant)│      │
│  └────────────────┘      │    │  └────────────────┘      │
└──────────────────────────┘    └──────────────────────────┘

Pros: Balance of cost and isolation
Cons: Regional coordination needed
```

---

## Security Model

```
┌─────────────────────────────────────────────────────────┐
│                   Authentication                         │
├─────────────────────────────────────────────────────────┤
│ Citizens (Public)                                        │
│  - No authentication required                            │
│  - Session-based                                         │
│  - Can download own application                          │
├─────────────────────────────────────────────────────────┤
│ State Staff (Admin)                                      │
│  - OAuth2 (Google / Azure AD)                            │
│  - Email-based access control                            │
│  - Role-based permissions:                               │
│    * ADMIN: Full access                                  │
│    * COUNTY_WORKER: County-scoped access                 │
│    * SUPPORT: Read-only                                  │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                   Data Security                          │
├─────────────────────────────────────────────────────────┤
│ At Rest                                                  │
│  - Database: application_data JSONB (AES256_GCM)         │
│  - Blob Storage: Encrypted by provider                   │
│  - Backups: Encrypted                                    │
├─────────────────────────────────────────────────────────┤
│ In Transit                                               │
│  - HTTPS/TLS 1.2+ required                               │
│  - SOAP over HTTPS                                       │
│  - SFTP with SSH keys                                    │
├─────────────────────────────────────────────────────────┤
│ Tenant Isolation                                         │
│  - All queries filtered by tenant_id                     │
│  - Row-level security (PostgreSQL RLS)                   │
│  - Admin users scoped to tenant                          │
└─────────────────────────────────────────────────────────┘
```

This completes the architecture documentation!

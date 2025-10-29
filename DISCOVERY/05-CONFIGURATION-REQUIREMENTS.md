# Configuration Requirements for Multi-State Support

## Current Configuration Model

### Environment-Based Profiles
**Current:** Hardcoded for Minnesota with 4 environments
- `default` - Local development
- `dev` - Development/staging
- `demo` - Demo environment
- `production` - Production environment

**Target:** State + Environment matrix
- `{state}-{environment}` (e.g., `mn-production`, `ca-production`)
- OR tenant-based configuration with database lookup

### Configuration Files
```
/src/main/resources/
├── application.yaml (base)
├── application-dev.yaml
├── application-demo.yaml
├── application-production.yaml
├── pages-config.yaml (form structure)
├── zip-to-county-mapping.yaml (Minnesota-specific)
├── personal-data-mappings.yaml (PII masking)
└── messages.properties (i18n)
```

## Required Configuration Dimensions

### 1. Geographic Configuration

#### Current (Minnesota):
- 87 counties (hardcoded enum)
- 11 tribal nations (hardcoded enum)
- Zip code to county mapping (YAML file)

#### Target (Multi-State):
```yaml
state:
  code: "MN"
  name: "Minnesota"
  timezone: "America/Chicago"

  regions:
    type: "county" # or "district", "parish", "region", etc.
    list:
      - code: "HENNEPIN"
        name: "Hennepin County"
        routing:
          email: "hennepin@state.mn.us"
          fax: "+15551234567"
          sftp: "sftp://hennepin.mn.gov/intake"
      - code: "RAMSEY"
        name: "Ramsey County"
        routing:
          email: "ramsey@state.mn.us"

  special_populations:
    - type: "tribal_nation"
      name: "Mille Lacs Band of Ojibwe"
      routing:
        email: "benefits@millelacsband.com"
        phone: "+12345678901"
        overrides_region: true  # Takes precedence over county

  zip_code_mapping:
    55001: "WASHINGTON"
    55002: "WASHINGTON"
    # ... or load from file
```

### 2. Program Configuration

#### Current (Minnesota):
- 6 hardcoded programs: SNAP, CASH, CCAP, GRH, EA, CERTAIN_POPS

#### Target (Multi-State):
```yaml
programs:
  - code: "SNAP"
    name: "Supplemental Nutrition Assistance Program"
    enabled: true
    federal: true  # Federal program, available in all states
    forms:
      - type: "APPLICATION"
        template: "snap-application.pdf"
    eligibility:
      expedited: true
      expedited_rules: "snap-expedited-rules.json"

  - code: "TANF"  # Different states call it different things
    name: "Temporary Assistance for Needy Families"
    enabled: true
    federal: true
    forms:
      - type: "APPLICATION"
        template: "tanf-application.pdf"

  - code: "STATE_SPECIFIC_PROGRAM"
    name: "Minnesota's CERTAIN_POPS"
    enabled: true
    federal: false
    state_specific: "MN"
    forms:
      - type: "APPLICATION"
        template: "certain-pops-form.pdf"
```

### 3. Document Type Configuration

#### Current (Minnesota):
- Hardcoded: CAF, CCAP, XML, UPLOADED_DOC, CERTAIN_POPS

#### Target (Multi-State):
```yaml
document_types:
  - code: "APPLICATION"
    name: "Benefits Application"
    required: true
    programs: ["SNAP", "TANF", "MEDICAID"]
    generation:
      method: "pdf_template"
      template: "templates/application.pdf"
    submission:
      channels: ["api", "email_fallback"]

  - code: "CHILD_CARE_APPLICATION"
    name: "Child Care Assistance Application"
    required: false
    programs: ["CCAP"]
    generation:
      method: "pdf_template"
      template: "templates/ccap.pdf"

  - code: "PROOF_OF_INCOME"
    name: "Income Verification"
    required: false
    user_uploaded: true
    accepted_formats: ["PDF", "JPG", "PNG"]
```

### 4. Integration Configuration

#### Current (Minnesota MNIT):
```yaml
mnit-filenet:
  username: ${MNIT-FILENET_USERNAME}
  password: ${MNIT-FILENET_PASSWORD}
  upload-url: https://test-svcs.dhs.mn.gov/WebServices/FileNet/ObjectService/SOAP
```

#### Target (Multi-State):
```yaml
integrations:
  document_submission:
    provider: "soap_api"  # soap_api, rest_api, sftp, email

    soap_api:
      endpoint: "https://benefits.state.mn.us/DocumentService"
      wsdl: "https://benefits.state.mn.us/DocumentService?wsdl"
      username: ${STATE_API_USERNAME}
      password: ${STATE_API_PASSWORD}
      timeout_seconds: 30
      retry:
        enabled: true
        max_attempts: 3
        backoff: "exponential"
        initial_delay_minutes: 90
        max_delay_minutes: 180

    rest_api:
      base_url: "https://api.benefits.state.example.gov"
      auth_method: "oauth2_client_credentials"
      client_id: ${API_CLIENT_ID}
      client_secret: ${API_CLIENT_SECRET}
      token_url: "https://auth.state.example.gov/token"
      endpoints:
        submit_application: "/v1/applications"
        check_status: "/v1/applications/{id}/status"

    sftp:
      host: "sftp.benefits.state.example.gov"
      port: 22
      username: ${SFTP_USERNAME}
      password: ${SFTP_PASSWORD}
      directory: "/intake"
      file_naming: "{application_id}_{document_type}_{timestamp}.pdf"

    email:
      routing_rules:
        - region: "HENNEPIN"
          to: "hennepin@benefits.state.example.gov"
        - region: "RAMSEY"
          to: "ramsey@benefits.state.example.gov"
        - default: "intake@benefits.state.example.gov"

  email_service:
    provider: "mailgun"  # mailgun, sendgrid, ses, smtp
    mailgun:
      domain: "mail.mnbenefits.mn.gov"
      api_key: ${MAILGUN_API_KEY}
      from_address: "help@mnbenefits.org"
      from_name: "MN Benefits"

    smtp:
      host: "smtp.state.example.gov"
      port: 587
      username: ${SMTP_USERNAME}
      password: ${SMTP_PASSWORD}
      tls: true

  address_validation:
    enabled: true
    provider: "smartystreets"  # smartystreets, usps, google, none
    smartystreets:
      auth_id: ${SMARTYSTREETS_AUTH_ID}
      auth_token: ${SMARTYSTREETS_AUTH_TOKEN}

  analytics:
    enabled: true
    provider: "mixpanel"  # mixpanel, google_analytics, none
    mixpanel:
      token: ${MIXPANEL_TOKEN}

  error_tracking:
    enabled: true
    provider: "sentry"
    sentry:
      dsn: ${SENTRY_DSN}
      environment: "production"
```

### 5. Business Rules Configuration

#### Current (Minnesota):
- Hardcoded in Java classes:
  - `ExpeditedEligibilityDecider.java`
  - `CcapExpeditedEligibilityDecider.java`

#### Target (Multi-State):
```yaml
eligibility_rules:
  snap_expedited:
    enabled: true
    rules_engine: "drools"  # or "json_logic", "groovy_script"
    rules_file: "rules/mn/snap-expedited.drl"
    # OR inline simple rules:
    conditions:
      - name: "very_low_income_high_expenses"
        eligible_if: "monthly_income < 150 && liquid_resources < 100"
      - name: "high_expenses_vs_income"
        eligible_if: "monthly_income + liquid_resources < monthly_expenses + 150"
      - name: "migrant_or_seasonal"
        eligible_if: "is_migrant_or_seasonal_worker && liquid_resources < 100"

  ccap_expedited:
    enabled: true
    rules_file: "rules/mn/ccap-expedited.drl"
```

### 6. Form Structure Configuration

#### Current (Minnesota):
- `pages-config.yaml` - 3000+ lines defining all form pages

#### Target (Multi-State):
```yaml
form:
  flow: "standard"  # standard, minimal, document_only

  pages:
    - name: "landing"
      template: "landing.html"
      title_key: "landing.title"
      next:
        - page: "language_preferences"

    - name: "choose_programs"
      template: "choose-programs.html"
      title_key: "choose-programs.title"
      inputs:
        - name: "programs"
          type: "checkbox_group"
          required: true
          options_from: "programs_config"  # Load from programs config
          validation:
            min_selections: 1
      conditional_next:
        - condition: "has_program('SNAP')"
          page: "snap_specific_page"
        - condition: "has_program('CCAP')"
          page: "ccap_specific_page"
        - default: "personal_info"

    - name: "personal_info"
      template: "personal-info.html"
      inputs:
        - name: "first_name"
          type: "text"
          required: true
          validation:
            max_length: 50
        - name: "ssn"
          type: "ssn"
          required: false
          help_text_key: "personal-info.ssn.help"

  subworkflows:
    household:
      entry_page: "household_member_info"
      iteration_page: "household_list"
      review_page: "household_review"
      max_iterations: 10
```

### 7. Localization Configuration

#### Current (Minnesota):
- English, Spanish, and other languages
- `messages.properties`, `messages_es.properties`

#### Target (Multi-State):
```yaml
localization:
  default_language: "en"
  supported_languages: ["en", "es", "hmn", "so"]  # English, Spanish, Hmong, Somali

  language_detection:
    use_browser_preference: true
    allow_user_selection: true

  translation_files:
    base_path: "messages"
    pattern: "messages_{lang}.properties"

  state_specific_overrides:
    # Allow state-specific terminology
    file: "messages_mn_overrides.properties"
    # e.g., "program.cash.name=MFIP" for MN vs "program.cash.name=TANF" for other states
```

### 8. Authentication & Authorization

#### Current (Minnesota):
- Hardcoded list of 9 admin emails
- Google OAuth (testing)
- Azure AD OAuth (production)

#### Target (Multi-State):
```yaml
authentication:
  public_access:
    enabled: true
    requires_login: false

  admin_access:
    method: "database"  # database, ldap, oauth, hardcoded

    oauth:
      providers:
        - name: "google"
          enabled: true
          client_id: ${GOOGLE_CLIENT_ID}
          client_secret: ${GOOGLE_CLIENT_SECRET}
          allowed_domains: ["state.mn.us"]

        - name: "azure_ad"
          enabled: true
          client_id: ${AZURE_CLIENT_ID}
          client_secret: ${AZURE_CLIENT_SECRET}
          tenant_id: ${AZURE_TENANT_ID}

    database:
      # Store admin users in database with roles
      roles:
        - name: "ADMIN"
          permissions: ["download_applications", "resend_emails", "view_all_applications"]
        - name: "COUNTY_WORKER"
          permissions: ["download_applications", "view_county_applications"]
          scope: "county"  # Only see their county's applications
```

### 9. Feature Flags

#### Current (Minnesota):
```yaml
feature-flag:
  submit-via-api: on
  certain-pops: on
  white-earth-and-red-lake-routing: on
```

#### Target (Multi-State):
```yaml
feature_flags:
  # Global flags
  document_upload: true
  expedited_eligibility: true
  address_validation: true

  # State-specific flags
  state_specific:
    mn:
      certain_pops_program: true
      tribal_nation_routing: true
    ca:
      county_consortium_routing: true

  # A/B testing flags
  experiments:
    simplified_application_flow:
      enabled: false
      rollout_percentage: 0
```

### 10. Notification Templates

#### Current:
- Hardcoded email templates in Thymeleaf

#### Target:
```yaml
notifications:
  confirmation_email:
    enabled: true
    template: "emails/confirmation.html"
    subject_key: "email.confirmation.subject"
    from: "${SYSTEM_EMAIL_FROM}"
    attachments:
      - type: "application_pdf"
        filename: "your_application.pdf"

  next_steps_email:
    enabled: true
    template: "emails/next_steps.html"
    subject_key: "email.next_steps.subject"
    timing: "immediate"  # immediate, delayed_1h, delayed_24h

  document_upload_notification:
    enabled: true
    template: "emails/doc_upload_confirmation.html"
    send_to_applicant: true
    send_to_caseworker: true
    caseworker_routing: "by_county"

  reminder_email:
    enabled: false
    template: "emails/reminder.html"
    timing: "7_days_after_submission"
```

## Configuration Management Strategy

### Option 1: File-Based (Current Approach Enhanced)
```
/src/main/resources/
└── states/
    ├── minnesota/
    │   ├── application-mn-production.yaml
    │   ├── programs.yaml
    │   ├── regions.yaml
    │   ├── integrations.yaml
    │   ├── pages-config.yaml
    │   └── messages_en.properties
    ├── california/
    │   ├── application-ca-production.yaml
    │   ├── programs.yaml
    │   └── ...
    └── default/
        └── (fallback configs)
```

**Pros:**
- Version controlled
- Easy to review changes
- Works well for small number of states

**Cons:**
- Requires rebuild for config changes
- Not ideal for 50+ states

### Option 2: Database-Driven (Recommended for Scale)
```sql
-- Tenant/State table
CREATE TABLE tenants (
  id VARCHAR PRIMARY KEY,
  state_code VARCHAR(2),
  name VARCHAR,
  timezone VARCHAR,
  config JSONB  -- Store entire config as JSON
);

-- Region/County table
CREATE TABLE regions (
  id VARCHAR PRIMARY KEY,
  tenant_id VARCHAR REFERENCES tenants(id),
  code VARCHAR,
  name VARCHAR,
  routing_email VARCHAR,
  routing_sftp VARCHAR,
  config JSONB
);

-- Program configuration
CREATE TABLE programs (
  id VARCHAR PRIMARY KEY,
  tenant_id VARCHAR REFERENCES tenants(id),
  code VARCHAR,
  name VARCHAR,
  enabled BOOLEAN,
  config JSONB
);
```

**Pros:**
- No rebuild needed for config changes
- True multi-tenancy
- Admin UI for configuration
- Can support 50+ states easily

**Cons:**
- More complex architecture
- Need admin interface
- Config changes not version controlled (solution: audit log)

### Option 3: Hybrid Approach (Recommended)
- **Base configuration:** File-based (default rules, structure)
- **State-specific overrides:** Database-driven
- **Secrets:** Environment variables
- **Form structure:** File-based (version controlled)
- **Business rules:** External rules engine (Drools files)

## Environment Variables Required

```bash
# Database
DATABASE_URL=jdbc:postgresql://localhost:5432/shiba
DATABASE_USERNAME=shiba_user
DATABASE_PASSWORD=***

# State Configuration
STATE_CODE=MN  # or load from database
TENANT_ID=minnesota

# Encryption
ENCRYPTION_KEY=***  # AES-256 key

# Document Submission
STATE_API_ENDPOINT=https://api.benefits.state.mn.us
STATE_API_USERNAME=***
STATE_API_PASSWORD=***

# Email
EMAIL_PROVIDER=mailgun
MAILGUN_DOMAIN=mail.mnbenefits.mn.gov
MAILGUN_API_KEY=***
SYSTEM_EMAIL_FROM=help@mnbenefits.org

# OAuth
GOOGLE_CLIENT_ID=***
GOOGLE_CLIENT_SECRET=***
AZURE_CLIENT_ID=***
AZURE_CLIENT_SECRET=***
AZURE_TENANT_ID=***

# External Services
SMARTYSTREETS_AUTH_ID=***
SMARTYSTREETS_AUTH_TOKEN=***
AZURE_STORAGE_CONNECTION_STRING=***
MIXPANEL_TOKEN=***
SENTRY_DSN=***

# Feature Flags (or load from DB)
FEATURE_DOCUMENT_UPLOAD=true
FEATURE_EXPEDITED_ELIGIBILITY=true
```

## Migration Path: Minnesota-Specific → Multi-State

### Phase 1: Extract State-Specific Configuration
1. Move County enum → `regions.yaml`
2. Move TribalNation enum → `special_populations.yaml`
3. Move Program enum → `programs.yaml`
4. Extract hardcoded emails → `contacts.yaml`
5. Extract routing logic → `routing.yaml`

### Phase 2: Create Configuration Abstraction Layer
1. Create `TenantConfigService` to load config
2. Replace hardcoded values with config lookups
3. Add config validation on startup

### Phase 3: Implement Multi-State Support
1. Add `tenant_id` to database
2. Create tenant management admin UI
3. Support multiple states in same deployment
4. Add tenant selection/detection logic

### Phase 4: Externalize Business Rules
1. Extract eligibility rules to rules engine
2. Make form flows configurable per state
3. Support state-specific document types

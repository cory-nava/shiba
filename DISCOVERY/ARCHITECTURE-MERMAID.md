# SHIBA Architecture Diagrams (Mermaid)

## Current Architecture (Minnesota-Specific)

### High-Level System Architecture

```mermaid
graph TB
    User[👤 User - Minnesota Citizen]

    subgraph "Spring Boot Application"
        PC[PageController<br/>Thymeleaf Templates]
        SM[Session Manager<br/>JDBC Store]
        Event[ApplicationSubmittedEvent<br/>Async Processing]

        subgraph "Event Listeners"
            PDF[PDF Generator<br/>Apache PDFBox]
            Email[Email Service<br/>Mailgun Client]
            FileNet[MNIT FileNet Client<br/>SOAP]
            Analytics[Mixpanel Tracker]
        end

        PC --> SM
        PC --> Event
        Event --> PDF
        Event --> Email
        Event --> FileNet
        Event --> Analytics
    end

    subgraph "External Services"
        Mailgun[📧 Mailgun API<br/>mail.mnbenefits.mn.gov]
        MNIT[🏛️ MNIT FileNet<br/>SOAP Web Service]
        Mixpanel[📊 Mixpanel Analytics]
    end

    subgraph "Storage"
        Azure[☁️ Azure Blob Storage<br/>Uploaded Documents]
        DB[(🗄️ PostgreSQL<br/>applications<br/>application_status<br/>spring_session)]
    end

    User -->|HTTPS| PC
    Email --> Mailgun
    FileNet --> MNIT
    Analytics --> Mixpanel
    PDF --> Azure
    PC --> DB
    FileNet --> DB

    style User fill:#e1f5ff
    style PC fill:#fff3cd
    style Event fill:#f8d7da
    style DB fill:#d4edda
    style MNIT fill:#f8d7da
```

### Current Data Flow - Application Submission

```mermaid
sequenceDiagram
    actor User
    participant PC as PageController
    participant Session as HTTP Session
    participant DB as PostgreSQL
    participant Event as Event Bus
    participant PDF as PDF Generator
    participant Email as Mailgun
    participant FileNet as MNIT FileNet

    User->>PC: Fill out form pages
    loop Each Page
        PC->>Session: Store form data
        PC->>User: Next page
    end

    User->>PC: POST /submit
    PC->>Session: Load all form data
    PC->>DB: Save Application (encrypted JSONB)
    PC->>Event: Publish ApplicationSubmittedEvent
    PC->>User: Redirect to confirmation

    par Async Processing
        Event->>PDF: Generate CAF/CCAP PDFs
        PDF->>Azure: Store PDFs
        PDF->>DB: Update status
    and
        Event->>Email: Send confirmation email
        Email->>Mailgun: POST /messages
    and
        Event->>FileNet: Submit documents via SOAP
        FileNet->>MNIT: UploadDocument request
        MNIT-->>FileNet: Response
        FileNet->>DB: Update application_status
    end
```

### Hardcoded Dependencies

```mermaid
graph LR
    subgraph "Hardcoded Enums"
        County[County Enum<br/>87 Minnesota Counties<br/>HENNEPIN, RAMSEY, etc.]
        Tribal[TribalNation Enum<br/>11 Tribal Nations<br/>MILLE_LACS, WHITE_EARTH, etc.]
        Programs[Program Enum<br/>SNAP, CCAP, CASH<br/>GRH, EA, CERTAIN_POPS]
    end

    subgraph "Hardcoded Config"
        TZ[Timezone<br/>America/Chicago]
        Email[Email Domain<br/>mail.mnbenefits.mn.gov]
        Admin[Admin Emails<br/>9 state staff emails]
        FileNetURL[MNIT FileNet URL<br/>test-svcs.dhs.mn.gov]
    end

    subgraph "Application Code"
        Routing[Routing Logic]
        Forms[Form Pages]
        Eligibility[Eligibility Rules]
        PDFGen[PDF Generation]
    end

    County --> Routing
    County --> Forms
    Tribal --> Routing
    Programs --> Forms
    Programs --> Eligibility
    Programs --> PDFGen
    TZ --> Forms
    Email --> Routing
    Admin --> Security[Security Config]
    FileNetURL --> Routing

    style County fill:#f8d7da
    style Tribal fill:#f8d7da
    style Programs fill:#f8d7da
    style TZ fill:#fff3cd
    style Email fill:#fff3cd
    style Admin fill:#fff3cd
    style FileNetURL fill:#f8d7da
```

---

## Target Architecture (Multi-State)

### Multi-Tenant System Architecture

```mermaid
graph TB
    subgraph Users
        UserMN[👤 Minnesota User]
        UserCA[👤 California User]
        UserTX[👤 Texas User]
    end

    LB[⚖️ Load Balancer<br/>Tenant Detection]

    subgraph "Spring Boot Application - Multi-Tenant"
        TC[Tenant Context Service<br/>Load tenant config]
        PC[PageController<br/>Tenant-aware routing]
        Event[ApplicationSubmittedEvent]

        subgraph "Pluggable Services"
            DocService[Document Submission Service<br/>Adapter Selection]
            EmailService[Email Service<br/>Provider Factory]
            StorageService[Storage Service<br/>Provider Factory]
        end

        TC --> PC
        PC --> Event
        Event --> DocService
        Event --> EmailService
        Event --> StorageService
    end

    subgraph "Document Submission Adapters"
        MNIT[MNIT FileNet Adapter<br/>Minnesota SOAP]
        REST[REST API Adapter<br/>Generic States]
        SFTP[SFTP Adapter<br/>File-based States]
        EmailAdapter[Email Adapter<br/>Simple States]
    end

    subgraph "Database - Multi-Tenant"
        DB[(PostgreSQL)]

        subgraph "Config Tables"
            Tenants[tenants<br/>state_code, timezone, config]
            Regions[regions<br/>tenant_id, code, routing]
            Programs[programs<br/>tenant_id, code, name]
            Integrations[integrations<br/>tenant_id, provider, config]
        end

        subgraph "Data Tables"
            Apps[applications<br/>tenant_id, region_code, data]
            Status[application_status<br/>document_type, status]
        end
    end

    UserMN -->|mn.benefits.gov| LB
    UserCA -->|ca.benefits.gov| LB
    UserTX -->|tx.benefits.gov| LB

    LB -->|tenant=MN| TC
    LB -->|tenant=CA| TC
    LB -->|tenant=TX| TC

    DocService --> MNIT
    DocService --> REST
    DocService --> SFTP
    DocService --> EmailAdapter

    TC --> DB
    PC --> DB
    DocService --> DB

    style TC fill:#d4edda
    style DocService fill:#d1ecf1
    style EmailService fill:#d1ecf1
    style StorageService fill:#d1ecf1
    style DB fill:#d4edda
    style Tenants fill:#fff3cd
    style Integrations fill:#fff3cd
```

### Multi-Tenant Request Flow

```mermaid
sequenceDiagram
    actor User
    participant LB as Load Balancer
    participant TCS as TenantContextService
    participant ConfigDB as Config DB
    participant PC as PageController
    participant AppDB as Application DB

    User->>LB: GET https://mn.benefits.gov/pages/personalInfo
    LB->>TCS: Extract tenant from domain
    Note over TCS: Subdomain = "mn"

    TCS->>ConfigDB: SELECT * FROM tenants WHERE state_code = 'MN'
    ConfigDB-->>TCS: Tenant config (timezone, programs, etc.)

    TCS->>ConfigDB: SELECT * FROM regions WHERE tenant_id = 'minnesota'
    ConfigDB-->>TCS: 87 Minnesota counties

    TCS->>ConfigDB: SELECT * FROM integrations WHERE tenant_id = 'minnesota'
    ConfigDB-->>TCS: MNIT FileNet config

    Note over TCS: Set ThreadLocal context
    TCS->>PC: Process request with tenant context

    PC->>ConfigDB: Load page config for tenant
    PC->>AppDB: Query applications WHERE tenant_id = 'minnesota'
    PC-->>User: Render page with MN branding
```

### Document Submission Adapter Pattern

```mermaid
graph TB
    App[Application Submitted]

    App --> DSS[Document Submission Service]

    DSS --> TConfig{Load Tenant Config}
    TConfig --> GetAdapter[Get Adapter from Config]

    GetAdapter --> Select{Select Adapter}

    Select -->|provider='mnit_filenet'| MNITAdapter[MNIT FileNet Adapter]
    Select -->|provider='rest_api'| RESTAdapter[REST API Adapter]
    Select -->|provider='sftp'| SFTPAdapter[SFTP Adapter]
    Select -->|provider='email'| EmailAdapter[Email Adapter]

    subgraph "MNIT FileNet Adapter"
        MNITAdapter --> BuildSOAP[Build SOAP Request]
        BuildSOAP --> SendSOAP[Send to FileNet]
        SendSOAP --> ParseResp[Parse SOAP Response]
    end

    subgraph "REST API Adapter"
        RESTAdapter --> BuildJSON[Build JSON Request]
        BuildJSON --> OAuth[Get OAuth Token]
        OAuth --> SendREST[POST to State API]
        SendREST --> ParseJSON[Parse JSON Response]
    end

    subgraph "SFTP Adapter"
        SFTPAdapter --> Connect[SSH Connect]
        Connect --> Upload[Upload PDF]
        Upload --> Verify[Verify Transfer]
    end

    subgraph "Email Adapter"
        EmailAdapter --> Route[Get Email from Region Config]
        Route --> Attach[Attach PDF]
        Attach --> SendEmail[Send via Email Service]
    end

    ParseResp --> UpdateDB[(Update Status in DB)]
    ParseJSON --> UpdateDB
    Verify --> UpdateDB
    SendEmail --> UpdateDB

    style DSS fill:#d1ecf1
    style Select fill:#fff3cd
    style UpdateDB fill:#d4edda
```

### Configuration Hierarchy

```mermaid
graph TB
    subgraph "Layer 1: Application Defaults"
        AppYAML[application.yaml<br/>Database, Server, Security]
    end

    subgraph "Layer 2: Tenant Config"
        TenantDB[(tenants table)]
        TenantData[state_code: MN<br/>timezone: America/Chicago<br/>default_language: en]
        TenantDB --> TenantData
    end

    subgraph "Layer 3: Regional Config"
        RegionDB[(regions table)]
        RegionData[HENNEPIN → email<br/>RAMSEY → email<br/>... 87 counties]
        RegionDB --> RegionData
    end

    subgraph "Layer 4: Program Config"
        ProgramDB[(programs table)]
        ProgramData[SNAP: enabled<br/>CCAP: enabled<br/>CERTAIN_POPS: enabled]
        ProgramDB --> ProgramData
    end

    subgraph "Layer 5: Integration Config"
        IntegrationDB[(integrations table)]
        IntegrationData[document_submission:<br/>  provider: mnit_filenet<br/>  endpoint: https://...]
        IntegrationDB --> IntegrationData
    end

    subgraph "Layer 6: Form Structure"
        FormYAML[pages-config.yaml<br/>Page definitions<br/>Conditional navigation]
    end

    subgraph "Layer 7: Business Rules"
        RulesDRL[snap-expedited.drl<br/>Eligibility thresholds<br/>Calculation logic]
    end

    AppYAML --> TenantDB
    TenantDB --> RegionDB
    RegionDB --> ProgramDB
    ProgramDB --> IntegrationDB
    IntegrationDB --> FormYAML
    FormYAML --> RulesDRL

    style AppYAML fill:#e7f3ff
    style TenantData fill:#d4edda
    style RegionData fill:#fff3cd
    style ProgramData fill:#f8d7da
    style IntegrationData fill:#d1ecf1
    style FormYAML fill:#e2d7f5
    style RulesDRL fill:#ffe7d1
```

---

## Database Schema

### Current Schema (Minnesota)

```mermaid
erDiagram
    applications ||--o{ application_status : "has many"
    applications {
        varchar id PK
        timestamp completed_at
        jsonb application_data
        varchar county
        bigint time_to_complete
        varchar flow
        varchar sentiment
        text feedback
    }

    application_status {
        varchar application_id FK
        varchar document_type
        varchar routing_destination
        varchar status
        timestamp created_at
        timestamp updated_at
    }

    spring_session ||--o{ spring_session_attributes : "has"
    spring_session {
        char primary_id PK
        char session_id
        bigint creation_time
        bigint last_access_time
        int max_inactive_interval
    }

    spring_session_attributes {
        char session_primary_id FK
        varchar attribute_name
        bytea attribute_bytes
    }
```

### Target Multi-Tenant Schema

```mermaid
erDiagram
    tenants ||--o{ regions : "has many"
    tenants ||--o{ programs : "has many"
    tenants ||--o{ integrations : "has many"
    tenants ||--o{ applications : "has many"

    tenants {
        varchar id PK
        varchar state_code
        varchar name
        varchar timezone
        varchar default_language
        jsonb config
    }

    regions {
        varchar id PK
        varchar tenant_id FK
        varchar code
        varchar name
        varchar type
        jsonb routing_config
    }

    programs {
        varchar id PK
        varchar tenant_id FK
        varchar code
        varchar name
        boolean enabled
        boolean federal
        jsonb config
    }

    integrations {
        varchar id PK
        varchar tenant_id FK
        varchar integration_type
        varchar provider
        jsonb config
        boolean enabled
    }

    applications {
        varchar id PK
        varchar tenant_id FK
        varchar region_code
        timestamp completed_at
        jsonb application_data
        varchar flow
    }

    applications ||--o{ application_status : "has many"

    application_status {
        varchar application_id FK
        varchar document_type
        varchar status
        timestamp created_at
    }
```

---

## Data Flow Diagrams

### Complete Application Flow (Multi-Tenant)

```mermaid
flowchart TD
    Start([User Visits Site])
    Start --> Detect{Detect Tenant}

    Detect -->|Subdomain: mn| LoadMN[Load Minnesota Config]
    Detect -->|Subdomain: ca| LoadCA[Load California Config]

    LoadMN --> SetContext[Set Tenant Context<br/>ThreadLocal]
    LoadCA --> SetContext

    SetContext --> Landing[Landing Page]
    Landing --> Programs[Choose Programs]
    Programs --> Personal[Personal Info Pages]

    Personal --> Loop{More Pages?}
    Loop -->|Yes| NextPage[Next Form Page]
    NextPage --> Session[(Store in Session)]
    Session --> Loop

    Loop -->|No| Review[Review Page]
    Review --> Submit[Submit Application]

    Submit --> SaveDB[(Save to Database<br/>tenant_id + encrypted data)]
    SaveDB --> Event[Publish Event]

    Event --> Async1[Async: Generate PDFs]
    Event --> Async2[Async: Send Email]
    Event --> Async3[Async: Submit to State]

    Async1 --> Storage[(Azure/S3 Storage)]
    Async2 --> EmailService[Email Provider]
    Async3 --> Adapter{Select Adapter}

    Adapter -->|MN| MNIT[MNIT FileNet SOAP]
    Adapter -->|CA| REST[State REST API]
    Adapter -->|Other| SFTP[SFTP Upload]

    MNIT --> UpdateStatus[(Update Status)]
    REST --> UpdateStatus
    SFTP --> UpdateStatus

    UpdateStatus --> Retry{Success?}
    Retry -->|No| Schedule[Schedule Retry<br/>Exponential Backoff]
    Retry -->|Yes| Complete([Application Complete])

    Schedule -->|After delay| Async3

    style Detect fill:#fff3cd
    style SetContext fill:#d4edda
    style SaveDB fill:#d4edda
    style Adapter fill:#d1ecf1
    style Complete fill:#d4edda
```

### Admin UI Workflow (Proposed)

```mermaid
flowchart LR
    Admin[State Admin User]

    Admin --> Login[Login<br/>OAuth2]
    Login --> Dashboard[Admin Dashboard]

    Dashboard --> Tenants[Manage Tenants]
    Dashboard --> Regions[Manage Regions]
    Dashboard --> Integrations[Integrations]
    Dashboard --> Monitor[Monitor Applications]

    Tenants --> CreateTenant[Create New Tenant]
    CreateTenant --> TenantForm[State Code<br/>Name<br/>Timezone<br/>Languages]
    TenantForm --> SaveTenant[(Save to DB)]

    Regions --> AddRegion[Add County/District]
    AddRegion --> RegionForm[Code<br/>Name<br/>Type<br/>Routing Config]
    RegionForm --> SaveRegion[(Save to DB)]

    Integrations --> ConfigIntegration[Configure Integration]
    ConfigIntegration --> SelectProvider{Provider Type}
    SelectProvider -->|SOAP| SOAPConfig[WSDL URL<br/>Auth Credentials]
    SelectProvider -->|REST| RESTConfig[API Endpoint<br/>OAuth Config]
    SelectProvider -->|SFTP| SFTPConfig[Host<br/>Username<br/>SSH Key]

    SOAPConfig --> TestIntegration[Test Connection]
    RESTConfig --> TestIntegration
    SFTPConfig --> TestIntegration

    TestIntegration --> Health{Health Check}
    Health -->|Pass| SaveIntegration[(Save Config)]
    Health -->|Fail| ShowError[Show Error<br/>Fix Config]

    Monitor --> ViewApps[View Applications]
    ViewApps --> FilterByRegion[Filter by Region]
    ViewApps --> FilterByStatus[Filter by Status]

    style Dashboard fill:#d1ecf1
    style SaveTenant fill:#d4edda
    style SaveRegion fill:#d4edda
    style SaveIntegration fill:#d4edda
    style Health fill:#fff3cd
```

---

## Integration Patterns

### Document Submission - SOAP (MNIT FileNet)

```mermaid
sequenceDiagram
    participant App as Application
    participant Adapter as MNIT FileNet Adapter
    participant SOAP as SOAP Client
    participant FileNet as MNIT FileNet
    participant DB as Database

    App->>Adapter: submit(application, pdf)
    Adapter->>Adapter: Build SOAP envelope

    Note over Adapter: Create XML structure<br/>with base64 PDF

    Adapter->>SOAP: Send SOAP request
    SOAP->>FileNet: POST /WebServices/FileNet/ObjectService/SOAP

    alt Success
        FileNet-->>SOAP: 200 OK + Success XML
        SOAP-->>Adapter: Parse response
        Adapter->>DB: UPDATE status = 'DELIVERED'
        Adapter-->>App: SubmissionResult(success=true)
    else Failure
        FileNet-->>SOAP: 500 Error or Timeout
        SOAP-->>Adapter: Exception
        Adapter->>DB: UPDATE status = 'DELIVERY_FAILED'
        Adapter->>Adapter: Schedule retry
        Adapter-->>App: SubmissionResult(success=false, retry=true)
    end
```

### Document Submission - REST API

```mermaid
sequenceDiagram
    participant App as Application
    participant Adapter as REST API Adapter
    participant OAuth as OAuth2 Token Service
    participant API as State API
    participant DB as Database

    App->>Adapter: submit(application, pdf)

    Adapter->>OAuth: POST /token<br/>(client_credentials)
    OAuth-->>Adapter: Access Token

    Adapter->>Adapter: Build JSON request
    Note over Adapter: {<br/>"applicant": {...},<br/>"document": "base64...",<br/>"metadata": {...}<br/>}

    Adapter->>API: POST /v1/applications<br/>Authorization: Bearer {token}

    alt Success
        API-->>Adapter: 201 Created<br/>{"id": "12345", "status": "received"}
        Adapter->>DB: UPDATE status = 'DELIVERED'<br/>external_id = '12345'
        Adapter-->>App: SubmissionResult(success=true)
    else API Error
        API-->>Adapter: 400/500 Error
        Adapter->>DB: UPDATE status = 'DELIVERY_FAILED'
        Adapter->>Adapter: Schedule retry
        Adapter-->>App: SubmissionResult(success=false, retry=true)
    else Auth Error
        API-->>Adapter: 401 Unauthorized
        Adapter->>OAuth: Refresh token
        Adapter->>API: Retry with new token
    end
```

### Document Submission - SFTP

```mermaid
sequenceDiagram
    participant App as Application
    participant Adapter as SFTP Adapter
    participant SFTP as SFTP Server
    participant DB as Database

    App->>Adapter: submit(application, pdf)

    Adapter->>SFTP: SSH Connect
    Note over Adapter,SFTP: Host: sftp.state.gov<br/>Port: 22<br/>Auth: SSH Key

    SFTP-->>Adapter: Connected

    Adapter->>Adapter: Generate filename<br/>{app_id}_{doc_type}_{timestamp}.pdf

    Adapter->>SFTP: PUT /intake/{filename}
    SFTP-->>Adapter: Upload complete

    Adapter->>SFTP: Verify file exists
    SFTP-->>Adapter: File confirmed

    Adapter->>SFTP: Disconnect

    Adapter->>DB: UPDATE status = 'DELIVERED'<br/>filename = '{filename}'
    Adapter-->>App: SubmissionResult(success=true)
```

### Email Provider Selection

```mermaid
flowchart TD
    EmailReq[Email Request]
    EmailReq --> LoadConfig[Load Tenant Config]
    LoadConfig --> CheckProvider{Email Provider?}

    CheckProvider -->|mailgun| Mailgun[Mailgun Provider]
    CheckProvider -->|sendgrid| SendGrid[SendGrid Provider]
    CheckProvider -->|ses| SES[AWS SES Provider]
    CheckProvider -->|smtp| SMTP[SMTP Provider]

    Mailgun --> MailgunAPI[POST api.mailgun.net/v3/messages]
    SendGrid --> SendGridAPI[POST api.sendgrid.com/v3/mail/send]
    SES --> SESAPI[AWS SDK: SendEmail]
    SMTP --> SMTPConn[SMTP Connection<br/>JavaMail]

    MailgunAPI --> Success{Sent?}
    SendGridAPI --> Success
    SESAPI --> Success
    SMTPConn --> Success

    Success -->|Yes| Log[Log Success]
    Success -->|No| Retry[Retry Queue]

    Log --> Done([Email Sent])
    Retry --> Done

    style CheckProvider fill:#fff3cd
    style Done fill:#d4edda
```

---

## Deployment Architectures

### Option 1: Multi-Tenant SaaS

```mermaid
graph TB
    subgraph "Load Balancer"
        LB[AWS ALB / Nginx<br/>SSL Termination<br/>Tenant Routing]
    end

    subgraph "Application Tier - Auto Scaling Group"
        App1[Spring Boot Instance 1]
        App2[Spring Boot Instance 2]
        App3[Spring Boot Instance 3]
    end

    subgraph "Database Tier"
        Primary[(PostgreSQL Primary<br/>RDS)]
        Replica1[(Read Replica 1)]
        Replica2[(Read Replica 2)]
    end

    subgraph "Storage Tier"
        S3[AWS S3<br/>Document Storage<br/>Tenant Isolated]
    end

    subgraph "Cache Layer"
        Redis[Redis Cluster<br/>Config Cache<br/>Session Cache]
    end

    Users[Multiple States' Users] -->|HTTPS| LB

    LB --> App1
    LB --> App2
    LB --> App3

    App1 --> Redis
    App2 --> Redis
    App3 --> Redis

    App1 --> Primary
    App2 --> Primary
    App3 --> Primary

    App1 -.->|Read| Replica1
    App2 -.->|Read| Replica1
    App3 -.->|Read| Replica2

    Primary -->|Replication| Replica1
    Primary -->|Replication| Replica2

    App1 --> S3
    App2 --> S3
    App3 --> S3

    style LB fill:#d1ecf1
    style Redis fill:#fff3cd
    style Primary fill:#d4edda
```

### Option 2: State-Isolated Deployments

```mermaid
graph TB
    subgraph "Minnesota Deployment"
        MNLB[Load Balancer]
        MNApp1[App Instance]
        MNApp2[App Instance]
        MNDB[(PostgreSQL<br/>MN Data Only)]
        MNStorage[S3 Bucket<br/>MN Documents]

        MNLB --> MNApp1
        MNLB --> MNApp2
        MNApp1 --> MNDB
        MNApp2 --> MNDB
        MNApp1 --> MNStorage
        MNApp2 --> MNStorage
    end

    subgraph "California Deployment"
        CALB[Load Balancer]
        CAApp1[App Instance]
        CAApp2[App Instance]
        CADB[(PostgreSQL<br/>CA Data Only)]
        CAStorage[S3 Bucket<br/>CA Documents]

        CALB --> CAApp1
        CALB --> CAApp2
        CAApp1 --> CADB
        CAApp2 --> CADB
        CAApp1 --> CAStorage
        CAApp2 --> CAStorage
    end

    UsersMN[Minnesota Users] -->|mn.benefits.gov| MNLB
    UsersCA[California Users] -->|ca.benefits.gov| CALB

    style MNDB fill:#d4edda
    style CADB fill:#d4edda
```

---

## Security Architecture

### Authentication & Authorization Flow

```mermaid
sequenceDiagram
    actor User
    participant App as Application
    participant OAuth as OAuth2 Provider<br/>(Google/Azure AD)
    participant DB as User Database
    participant Session as Session Store

    rect rgb(230, 240, 255)
        Note over User,Session: Public User (Citizen)
        User->>App: Access application
        App->>Session: Create session
        Session-->>App: Session ID
        App-->>User: Form pages (no auth required)
    end

    rect rgb(255, 240, 230)
        Note over User,Session: Admin User (State Staff)
        User->>App: Access /admin
        App->>User: Redirect to OAuth login
        User->>OAuth: Login with credentials
        OAuth->>User: Authorization code
        User->>App: Callback with code
        App->>OAuth: Exchange code for token
        OAuth-->>App: Access token + user info
        App->>DB: Check user permissions<br/>WHERE email = ? AND tenant_id = ?
        DB-->>App: User roles: ADMIN, COUNTY_WORKER
        App->>Session: Store user context
        App-->>User: Admin dashboard
    end
```

### Data Security Layers

```mermaid
graph TB
    subgraph "Application Layer"
        App[Spring Boot App]
        Encrypt[AES-256-GCM Encryption]
        App --> Encrypt
    end

    subgraph "Network Layer"
        TLS[TLS 1.3<br/>HTTPS Only]
    end

    subgraph "Database Layer"
        DB[(PostgreSQL)]
        RLS[Row Level Security<br/>Filter by tenant_id]
        EncAtRest[Encryption at Rest<br/>AWS RDS/Azure SQL]

        DB --> RLS
        DB --> EncAtRest
    end

    subgraph "Storage Layer"
        S3[Object Storage]
        S3Enc[Server-Side Encryption<br/>AES-256]

        S3 --> S3Enc
    end

    subgraph "Tenant Isolation"
        TenantFilter[Tenant Context Filter]
        QueryFilter[Query Interceptor<br/>Auto-add tenant_id]

        TenantFilter --> QueryFilter
    end

    User[User Request] -->|HTTPS| TLS
    TLS --> App
    Encrypt -->|Encrypted JSONB| DB
    App --> S3

    App --> TenantFilter
    QueryFilter --> DB

    style TLS fill:#d4edda
    style Encrypt fill:#d4edda
    style RLS fill:#fff3cd
    style EncAtRest fill:#d4edda
    style S3Enc fill:#d4edda
    style TenantFilter fill:#f8d7da
```

### Tenant Isolation Pattern

```mermaid
flowchart TD
    Request[Incoming Request]
    Request --> TenantFilter[Tenant Context Filter]

    TenantFilter --> Extract{Extract Tenant}
    Extract -->|Subdomain| FromDomain[mn.benefits.gov → MN]
    Extract -->|Session| FromSession[Session tenant_id]
    Extract -->|Admin| FromAuth[OAuth user → tenant]

    FromDomain --> Set[Set ThreadLocal Context]
    FromSession --> Set
    FromAuth --> Set

    Set --> Validate{Validate Tenant}
    Validate -->|Invalid| Error403[403 Forbidden]
    Validate -->|Valid| LoadConfig[Load Tenant Config]

    LoadConfig --> Controller[Controller Method]

    Controller --> Repository[Repository Query]
    Repository --> Interceptor[Query Interceptor]

    Interceptor --> AddFilter[Add WHERE tenant_id = ?]
    AddFilter --> Database[(Execute Query)]

    Database --> CheckRLS{Row Level Security}
    CheckRLS -->|Pass| ReturnData[Return Filtered Data]
    CheckRLS -->|Fail| Error403_2[403 Forbidden]

    ReturnData --> Response[HTTP Response]

    style TenantFilter fill:#fff3cd
    style Set fill:#d4edda
    style Interceptor fill:#d1ecf1
    style CheckRLS fill:#f8d7da
```

---

## Migration Strategy

### Phase-by-Phase Migration

```mermaid
gantt
    title Multi-State Transformation Timeline
    dateFormat YYYY-MM-DD
    section Phase 1
    Extract MN Logic          :p1, 2024-01-01, 6w
    Configuration Service     :p1a, 2024-01-01, 2w
    County to Region          :p1b, after p1a, 2w
    Tribal to Special Pops    :p1c, after p1b, 2w

    section Phase 2
    Integration Adapters      :p2, after p1, 8w
    Define Interfaces         :p2a, after p1, 1w
    MNIT Adapter Refactor     :p2b, after p2a, 2w
    REST/SFTP/Email Adapters  :p2c, after p2b, 5w

    section Phase 3
    Database Multi-Tenancy    :p3, after p1, 4w
    Add Tenant Tables         :p3a, after p1, 1w
    Migrate MN Data           :p3b, after p3a, 1w
    Update Repositories       :p3c, after p3b, 2w

    section Phase 4
    Pilot State               :p4, after p2, 8w
    Select State              :p4a, after p2, 1w
    Configure Pilot           :p4b, after p4a, 2w
    Deploy & Test             :p4c, after p4b, 3w
    Go Live                   :p4d, after p4c, 2w

    section Phase 5
    Business Rules            :p5, after p3, 6w
    Rules Engine Setup        :p5a, after p3, 2w
    Extract Eligibility       :p5b, after p5a, 4w

    section Phase 6
    Admin UI                  :p6, after p4, 12w
    API Design                :p6a, after p4, 2w
    Frontend Development      :p6b, after p6a, 8w
    Testing & Polish          :p6c, after p6b, 2w
```

### Data Migration Process

```mermaid
flowchart TD
    Start([Start Migration])

    Start --> Backup[Full Database Backup]
    Backup --> CreateTables[Create New Tables<br/>tenants, regions, programs]

    CreateTables --> InsertMN[Insert Minnesota Tenant<br/>INSERT INTO tenants]
    InsertMN --> ImportRegions[Import 87 Counties<br/>County enum → regions table]
    ImportRegions --> ImportPrograms[Import Programs<br/>SNAP, CCAP, etc.]

    ImportPrograms --> AlterApps[Alter applications table<br/>ADD COLUMN tenant_id]
    AlterApps --> UpdateApps[UPDATE applications<br/>SET tenant_id = 'minnesota']

    UpdateApps --> AddConstraints[Add Foreign Keys<br/>Add Indexes]
    AddConstraints --> UpdateCode[Deploy Code Changes<br/>Use tenant_id in queries]

    UpdateCode --> Validate{Validation Tests}
    Validate -->|Fail| Rollback[Rollback to Backup]
    Validate -->|Pass| Monitor[Monitor Production]

    Monitor --> Verify{All Working?}
    Verify -->|No| Investigate[Investigate Issues]
    Verify -->|Yes| Complete([Migration Complete])

    Investigate --> Fix[Fix Issues]
    Fix --> Verify

    Rollback --> Investigate2[Root Cause Analysis]
    Investigate2 --> FixMigration[Fix Migration Script]
    FixMigration --> Start

    style Backup fill:#fff3cd
    style Rollback fill:#f8d7da
    style Complete fill:#d4edda
```

This provides comprehensive visual documentation of the entire SHIBA architecture transformation using Mermaid diagrams!

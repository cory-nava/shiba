# Tenant Context - Detailed Diagrams

## Tenant Detection and Resolution

```mermaid
flowchart TD
    Request[Incoming HTTP Request]

    Request --> Filter[TenantContextFilter<br/>Servlet Filter]

    Filter --> Method{Detection Method}

    Method -->|Subdomain| ParseDomain[Parse Subdomain<br/>mn.benefits.gov]
    Method -->|Custom Domain| LookupDomain[Lookup Domain Mapping<br/>apply.mnbenefits.org]
    Method -->|Path Prefix| ParsePath[Parse URL Path<br/>/mn/pages/...]
    Method -->|Session| GetSession[Get from Session<br/>Previously set]

    ParseDomain --> ExtractTenant[Extract: tenant=mn]
    LookupDomain --> DBLookup[(Query domain_mappings table)]
    ParsePath --> ExtractTenant
    GetSession --> ExtractTenant

    DBLookup --> ExtractTenant

    ExtractTenant --> LoadTenant{Tenant exists?}

    LoadTenant -->|No| Error404[404 - Tenant Not Found]
    LoadTenant -->|Yes| LoadConfig[Load Tenant Config]

    LoadConfig --> Cache{In cache?}
    Cache -->|Yes| FromCache[Get from Redis/Caffeine]
    Cache -->|No| FromDB[(Load from Database)]

    FromDB --> StoreCache[Store in cache]
    StoreCache --> SetContext

    FromCache --> SetContext[Set ThreadLocal Context]

    SetContext --> Context[TenantContext]

    Context --> Properties[tenant_id<br/>state_code<br/>timezone<br/>default_language<br/>config]

    Properties --> Proceed[Proceed to Controller]

    Error404 --> Response([Return 404])

    style Filter fill:#fff3cd
    style LoadConfig fill:#d1ecf1
    style SetContext fill:#d4edda
    style Error404 fill:#f8d7da
```

## Tenant Configuration Caching Strategy

```mermaid
sequenceDiagram
    participant Request
    participant Filter as TenantContextFilter
    participant Cache as Redis/Caffeine Cache
    participant DB as PostgreSQL
    participant ThreadLocal as ThreadLocal Context

    Request->>Filter: HTTP Request (subdomain=mn)
    Filter->>Filter: Extract tenant ID from subdomain

    Filter->>Cache: GET tenant:mn:config
    alt Cache Hit
        Cache-->>Filter: Tenant config (cached)
        Note over Cache,Filter: TTL: 5 minutes
    else Cache Miss
        Cache-->>Filter: null
        Filter->>DB: SELECT * FROM tenants WHERE id = 'mn'
        DB->>DB: JOIN regions, programs, integrations
        DB-->>Filter: Complete tenant config
        Filter->>Cache: SET tenant:mn:config<br/>EXPIRE 300
        Cache-->>Filter: OK
    end

    Filter->>ThreadLocal: Set tenant context
    ThreadLocal-->>Filter: Context stored

    Filter->>Request: Continue to controller
    Note over Request: All subsequent code<br/>can access TenantContext
```

## Tenant Context Access Patterns

```mermaid
classDiagram
    class TenantContext {
        -String tenantId
        -String stateCode
        -ZoneId timezone
        -String defaultLanguage
        -Map~String,Object~ config
        +getTenantId() String
        +getStateCode() String
        +getTimezone() ZoneId
        +getConfig(String key) Object
    }

    class TenantContextHolder {
        -ThreadLocal~TenantContext~ context
        +setContext(TenantContext) void
        +getContext() TenantContext
        +clear() void
    }

    class TenantConfigurationService {
        +loadTenantConfig(String tenantId) TenantContext
        +getRegions(String tenantId) List~Region~
        +getPrograms(String tenantId) List~Program~
        +getIntegration(String tenantId, String type) Integration
    }

    class PageController {
        +showPage(String pageName) String
        +submitPage(String pageName, Map data) String
    }

    TenantContextHolder --> TenantContext
    PageController ..> TenantContextHolder : uses
    TenantConfigurationService ..> TenantContext : creates
```

## Multi-Tenant Request Lifecycle

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant LB as Load Balancer
    participant Filter as TenantContextFilter
    participant TCS as TenantConfigService
    participant PC as PageController
    participant Repo as ApplicationRepository
    participant DB as Database

    User->>LB: GET https://mn.benefits.gov/pages/personalInfo
    LB->>Filter: Route request

    rect rgb(230, 240, 255)
        Note over Filter,TCS: Tenant Resolution Phase
        Filter->>Filter: Extract subdomain: "mn"
        Filter->>TCS: loadTenantConfig("mn")
        TCS->>DB: Load tenant config
        DB-->>TCS: Tenant config
        TCS-->>Filter: TenantContext
        Filter->>ThreadLocal: Set context
    end

    Filter->>PC: Continue to controller

    rect rgb(255, 240, 230)
        Note over PC,DB: Request Processing Phase
        PC->>ThreadLocal: Get tenant context
        ThreadLocal-->>PC: TenantContext (tenant_id=mn)

        PC->>PC: Load page config for tenant
        PC->>PC: Apply timezone: America/Chicago

        PC->>Repo: findById(applicationId)
        Repo->>Repo: Add WHERE tenant_id = 'mn'
        Repo->>DB: SELECT * FROM applications<br/>WHERE id = ? AND tenant_id = 'mn'
        DB-->>Repo: Application data
        Repo-->>PC: Application
    end

    PC-->>User: Render page with MN branding

    rect rgb(230, 255, 240)
        Note over Filter: Cleanup Phase
        User->>Filter: Request complete
        Filter->>ThreadLocal: Clear context
    end
```

## Tenant Isolation - Database Query Interceptor

```mermaid
flowchart TD
    Query[Repository Query]
    Query --> Intercept[Hibernate Interceptor<br/>onPrepareStatement]

    Intercept --> Analyze{Analyze Query}

    Analyze -->|SELECT| AddWhere[Add WHERE tenant_id = ?]
    Analyze -->|INSERT| AddColumn[Add tenant_id column]
    Analyze -->|UPDATE| AddWhere
    Analyze -->|DELETE| AddWhere

    AddWhere --> GetTenant[Get from ThreadLocal]
    AddColumn --> GetTenant

    GetTenant --> Context{Context exists?}

    Context -->|No| Error[SecurityException<br/>No tenant context]
    Context -->|Yes| Bind[Bind tenant_id parameter]

    Bind --> Modified[Modified Query]

    Modified --> Examples

    subgraph Examples[Query Examples]
        direction TB
        E1[Original: SELECT * FROM applications WHERE id = ?]
        E2[Modified: SELECT * FROM applications<br/>WHERE id = ? AND tenant_id = 'mn']
        E1 --> E2

        E3[Original: INSERT INTO applications<br/>VALUES ?, ?, ?]
        E4[Modified: INSERT INTO applications<br/>VALUES ?, ?, ?, 'mn']
        E3 --> E4
    end

    Modified --> Execute[(Execute Query)]

    Error --> Fail([Query Rejected])

    style Intercept fill:#fff3cd
    style GetTenant fill:#d1ecf1
    style Error fill:#f8d7da
    style Execute fill:#d4edda
```

## Tenant-Aware Repository Pattern

```mermaid
classDiagram
    class TenantAwareRepository~T~ {
        <<interface>>
        +findAll() List~T~
        +findById(ID id) Optional~T~
        +save(T entity) T
        +delete(T entity) void
    }

    class JpaRepository~T~ {
        <<interface>>
        +findAll() List~T~
        +findById(ID id) Optional~T~
        +save(T entity) T
    }

    class ApplicationRepository {
        <<interface>>
        +findByCompletedAtAfter(Instant date) List~Application~
        +findByRegionCode(String region) List~Application~
        +countByTenantIdAndFlow(String tenantId, Flow flow) Long
    }

    class TenantFilterAspect {
        <<@Aspect>>
        +filterByTenant(ProceedingJoinPoint) Object
    }

    TenantAwareRepository --|> JpaRepository
    ApplicationRepository --|> TenantAwareRepository
    TenantFilterAspect ..> ApplicationRepository : intercepts

    note for TenantFilterAspect "Automatically adds tenant_id filter\nto all repository queries"
```

## Tenant Configuration Schema

```mermaid
erDiagram
    TENANTS ||--o{ REGIONS : has
    TENANTS ||--o{ PROGRAMS : has
    TENANTS ||--o{ DOCUMENT_TYPES : has
    TENANTS ||--o{ INTEGRATIONS : has
    TENANTS ||--o{ DOMAIN_MAPPINGS : has
    TENANTS ||--o{ ADMIN_USERS : has

    TENANTS {
        varchar id PK
        varchar state_code UK
        varchar name
        varchar timezone
        varchar default_language
        jsonb branding
        jsonb config
        timestamp created_at
        timestamp updated_at
    }

    REGIONS {
        varchar id PK
        varchar tenant_id FK
        varchar code
        varchar name
        varchar type
        jsonb routing_config
        int display_order
    }

    PROGRAMS {
        varchar id PK
        varchar tenant_id FK
        varchar code
        varchar name
        boolean enabled
        boolean federal
        jsonb eligibility_config
    }

    DOCUMENT_TYPES {
        varchar id PK
        varchar tenant_id FK
        varchar code
        varchar name
        boolean required
        boolean user_uploaded
        jsonb generation_config
    }

    INTEGRATIONS {
        varchar id PK
        varchar tenant_id FK
        varchar integration_type
        varchar provider
        jsonb config
        boolean enabled
    }

    DOMAIN_MAPPINGS {
        varchar id PK
        varchar tenant_id FK
        varchar domain UK
        varchar subdomain
        boolean is_primary
    }

    ADMIN_USERS {
        varchar id PK
        varchar tenant_id FK
        varchar email UK
        varchar role
        jsonb permissions
    }
```

## Tenant Context Propagation (Async Tasks)

```mermaid
sequenceDiagram
    participant Request as HTTP Request Thread
    participant Context as ThreadLocal Context
    participant Event as ApplicationSubmittedEvent
    participant Listener as Async Event Listener
    participant TaskContext as Copied Context

    Request->>Context: Set TenantContext<br/>(tenant_id=mn)
    Request->>Request: Process request

    Request->>Event: Publish event
    Note over Request,Event: Context still in ThreadLocal

    Request->>Listener: @EventListener (async)
    Note over Listener: New thread started

    par Context Propagation
        Request->>TaskContext: Copy context to TaskDecorator
        TaskContext->>Listener: Provide context
    and Original Request Completes
        Request->>Context: Clear ThreadLocal
        Request-->>Client: Response sent
    end

    Listener->>TaskContext: Get tenant context
    TaskContext-->>Listener: TenantContext (tenant_id=mn)

    Note over Listener: Can now access tenant-specific config

    Listener->>Listener: Generate PDFs for tenant
    Listener->>Listener: Submit to tenant's integration

    Listener->>TaskContext: Clear context
```

## Tenant Context Configuration

```java
@Configuration
public class TenantContextConfiguration {

    @Bean
    public FilterRegistrationBean<TenantContextFilter> tenantContextFilter() {
        FilterRegistrationBean<TenantContextFilter> registration = new FilterRegistrationBean<>();
        registration.setFilter(new TenantContextFilter(tenantConfigurationService()));
        registration.addUrlPatterns("/*");
        registration.setOrder(1); // Run first
        return registration;
    }

    @Bean
    public TaskDecorator tenantContextTaskDecorator() {
        return runnable -> {
            // Capture context from current thread
            TenantContext context = TenantContextHolder.getContext();

            // Return decorated runnable that sets context in new thread
            return () -> {
                try {
                    TenantContextHolder.setContext(context);
                    runnable.run();
                } finally {
                    TenantContextHolder.clear();
                }
            };
        };
    }

    @Bean
    public Executor asyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(10);
        executor.setMaxPoolSize(20);
        executor.setQueueCapacity(500);
        executor.setThreadNamePrefix("tenant-async-");
        executor.setTaskDecorator(tenantContextTaskDecorator());
        executor.initialize();
        return executor;
    }
}
```

## Tenant Switching (Admin Use Case)

```mermaid
flowchart TD
    Admin[Admin User Login]
    Admin --> Auth[Authenticate via OAuth]
    Auth --> CheckPerms{Check Permissions}

    CheckPerms -->|Super Admin| AllTenants[Can access all tenants]
    CheckPerms -->|Tenant Admin| OneTenant[Can only access assigned tenant]
    CheckPerms -->|County Worker| OneCounty[Can only access assigned county]

    AllTenants --> Dashboard[Admin Dashboard]
    OneTenant --> Dashboard
    OneCounty --> Dashboard

    Dashboard --> SelectTenant[Select Tenant from Dropdown]

    SelectTenant --> Validate{User has access?}

    Validate -->|No| Error403[403 Forbidden]
    Validate -->|Yes| SetSession[Set tenant_id in session]

    SetSession --> SwitchContext[Switch TenantContext]

    SwitchContext --> LoadData[Load data for selected tenant]

    LoadData --> Display[Display tenant-specific data]

    Display --> Actions{Admin Actions}

    Actions --> ViewApps[View Applications]
    Actions --> ConfigRegions[Configure Regions]
    Actions --> TestIntegrations[Test Integrations]

    ViewApps --> Filter[Filter: WHERE tenant_id = selected]
    ConfigRegions --> Filter
    TestIntegrations --> Filter

    style Admin fill:#d1ecf1
    style SelectTenant fill:#fff3cd
    style Validate fill:#f8d7da
    style Display fill:#d4edda
```

## Performance: Tenant Config Caching

```mermaid
graph TB
    subgraph "Cache Strategy"
        L1[L1 Cache: Application Memory<br/>Caffeine - 5 min TTL<br/>100 entries max]
        L2[L2 Cache: Redis<br/>5 min TTL<br/>Shared across instances]
        DB[(Database<br/>Source of truth)]
    end

    Request[Request for tenant config]
    Request --> CheckL1{Check L1}

    CheckL1 -->|Hit| ReturnL1[Return from memory]
    CheckL1 -->|Miss| CheckL2{Check L2}

    CheckL2 -->|Hit| UpdateL1[Update L1]
    CheckL2 -->|Miss| LoadDB[Load from DB]

    UpdateL1 --> ReturnL2[Return from L2]
    LoadDB --> UpdateL2[Update L2]
    UpdateL2 --> UpdateL12[Update L1]
    UpdateL12 --> ReturnDB[Return from DB]

    ReturnL1 --> Response[Response Time: 1ms]
    ReturnL2 --> Response2[Response Time: 10ms]
    ReturnDB --> Response3[Response Time: 50ms]

    subgraph "Cache Invalidation"
        Update[Config Updated<br/>via Admin UI]
        Update --> InvalidateL1[Clear L1 cache]
        Update --> InvalidateL2[Clear L2 cache]
        InvalidateL1 --> NextReq[Next request reloads]
        InvalidateL2 --> NextReq
    end

    style CheckL1 fill:#d4edda
    style CheckL2 fill:#fff3cd
    style LoadDB fill:#f8d7da
    style Response fill:#d4edda
```

This provides comprehensive visual documentation for the tenant context and multi-tenancy architecture!

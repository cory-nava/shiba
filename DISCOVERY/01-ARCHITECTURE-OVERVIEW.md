# Architecture Overview

## System Purpose
SHIBA (State Hosted Integrated Benefits Application) is a Spring Boot-based web application designed for Minnesota residents to apply for state benefit programs including SNAP, CCAP, CASH, GRH, EA, and CERTAIN_POPS.

## Technology Stack

### Backend
- **Framework:** Spring Boot 2.7.1
- **Language:** Java 17
- **Build Tool:** Gradle
- **Database:** PostgreSQL 11
- **Key Dependencies:**
  - Spring Security (OAuth2)
  - Spring WebFlux (async HTTP)
  - Thymeleaf (templating)
  - Flyway (migrations)

### Frontend
- **Template Engine:** Thymeleaf
- **Standards:** HTML5, CSS3, JavaScript
- **Assets Location:** `/src/main/resources/templates/` and `/src/main/resources/static/`

### External Libraries
- **Apache PDFBox** - PDF generation
- **Azure Storage Blob SDK** - Document storage
- **Mailgun** - Email service
- **Google Tink** - AES256_GCM encryption
- **OpenCMIS** - Document management
- **Sentry** - Error tracking
- **Mixpanel** - Analytics
- **ShedLock** - Distributed locking

## Application Entry Points

### Main Application
- **File:** `/src/main/java/org/codeforamerica/shiba/ShibaApplication.java`
- **Port:** 8080 (default)
- **Session Store:** JDBC-backed (60-minute timeout)

### Key Controllers
1. **PageController** - `/src/main/java/org/codeforamerica/shiba/pages/PageController.java`
   - Handles form navigation and submission
2. **FileDownloadController** - PDF download endpoints
3. **ResendFailedEmailController** - Admin email retry

## Architecture Patterns

### Form Engine
- Dynamic page navigation based on YAML configuration
- Conditional page display logic
- Session-based form state management
- Validation at page and field levels

### Event-Driven Processing
- Application submission triggers async events
- Multiple listeners handle document generation, email, and submission to state systems
- Retry logic with exponential backoff

### Multi-Tenant Considerations
- County-based routing (87 Minnesota counties)
- Tribal nation support (11 nations)
- Per-environment configuration profiles

## Deployment Architecture
- **Profiles:** default, dev, demo, test, production
- **Containerization:** Docker support
- **Web Server:** Embedded Tomcat
- **Load Balancing:** Session affinity required (JDBC session store enables multi-instance)

## Security Architecture
- OAuth2 authentication (Google + Azure AD)
- AES256_GCM encryption for PII
- SSL/TLS client certificates
- Admin access via hardcoded email allowlist
- CSRF protection enabled

# External Integration Mapping

## Overview
This document maps all external service integrations and provides abstraction patterns for multi-state support.

## 1. Document Submission Integration (MNIT FileNet)

### Current Implementation

#### Primary: SOAP Web Service
**File:** `/src/main/java/org/codeforamerica/shiba/mnit/FilenetWebServiceClient.java`

**Endpoint:**
- Test: `https://test-svcs.dhs.mn.gov/WebServices/FileNet/ObjectService/SOAP`
- Production: (configured per environment)

**Protocol:** SOAP 1.1 / WSDL

**Authentication:**
- Basic authentication
- Username: `${MNIT-FILENET_USERNAME}`
- Password: `${MNIT-FILENET_PASSWORD}`

**Operations:**
```java
public class FilenetWebServiceClient {
    // Submit CAF document
    public void send(Application application, byte[] pdfBytes) {
        // Build SOAP request
        // Send via WebClient
        // Handle response
    }
}
```

**Request Structure:**
```xml
<soapenv:Envelope>
  <soapenv:Header/>
  <soapenv:Body>
    <tem:UploadDocument>
      <tem:documentRequest>
        <tem:DocumentClass>CAF</tem:DocumentClass>
        <tem:DocumentContent>[Base64 PDF]</tem:DocumentContent>
        <tem:County>HENNEPIN</tem:County>
        <tem:ApplicationNumber>[UUID]</tem:ApplicationNumber>
        <tem:DateReceived>2024-01-15</tem:DateReceived>
        <tem:MetaData>
          <tem:ApplicantName>John Doe</tem:ApplicantName>
          <tem:ProgramsRequested>SNAP,CASH</tem:ProgramsRequested>
        </tem:MetaData>
      </tem:documentRequest>
    </tem:UploadDocument>
  </soapenv:Body>
</soapenv:Envelope>
```

**Response Handling:**
- Success: `<Success>true</Success>`
- Failure: Exponential backoff retry

#### Secondary: ESB Web Service
**File:** `/src/main/java/org/codeforamerica/shiba/mnit/MnitEsbWebServiceClient.java`

Similar to FileNet but uses ESB endpoint for XML metadata submission.

#### Tertiary: SFTP Fallback
**Router:** `/router/api/fileNetToSftp`

If SOAP fails after retries, documents are sent via SFTP.

### Multi-State Abstraction

#### Proposed Interface
```java
public interface DocumentSubmissionService {
    /**
     * Submit application document to state system
     */
    SubmissionResult submitDocument(
        String applicationId,
        DocumentType documentType,
        byte[] documentBytes,
        Map<String, String> metadata
    );

    /**
     * Check submission status
     */
    SubmissionStatus checkStatus(String applicationId, DocumentType documentType);

    /**
     * Retry failed submission
     */
    SubmissionResult retrySubmission(String applicationId, DocumentType documentType);
}
```

#### Implementation Options

**Option A: SOAP-based States**
```java
@Component
@ConditionalOnProperty(name = "integrations.document_submission.provider", havingValue = "soap_api")
public class SoapDocumentSubmissionService implements DocumentSubmissionService {
    // Generic SOAP client
    // Configurable via WSDL URL
    // Mapping layer for state-specific request/response formats
}
```

**Option B: REST API-based States**
```java
@Component
@ConditionalOnProperty(name = "integrations.document_submission.provider", havingValue = "rest_api")
public class RestApiDocumentSubmissionService implements DocumentSubmissionService {
    // Generic REST client
    // Configurable endpoints
    // Support multiple auth methods (OAuth2, API Key, Basic Auth)
}
```

**Option C: SFTP-based States**
```java
@Component
@ConditionalOnProperty(name = "integrations.document_submission.provider", havingValue = "sftp")
public class SftpDocumentSubmissionService implements DocumentSubmissionService {
    // SFTP client (JSch or Apache Commons VFS)
    // Configurable host, credentials, directory
    // File naming convention from config
}
```

**Option D: Email-based States**
```java
@Component
@ConditionalOnProperty(name = "integrations.document_submission.provider", havingValue = "email")
public class EmailDocumentSubmissionService implements DocumentSubmissionService {
    // Send documents as email attachments
    // Route based on county/region config
    // Track email delivery status
}
```

**Option E: Multi-Channel (Hybrid)**
```java
@Component
public class HybridDocumentSubmissionService implements DocumentSubmissionService {
    // Route different document types to different channels
    // E.g., CAF via API, UPLOADED_DOCS via email
    // Configured per state, per document type
}
```

---

## 2. Email Service Integration (Mailgun)

### Current Implementation

**File:** `/src/main/java/org/codeforamerica/shiba/pages/emails/MailGunEmailClient.java`

**Endpoint:** `https://api.mailgun.net/v3/mail.mnbenefits.mn.gov/messages`

**Authentication:** Basic auth with API key

**Operations:**
```java
public class MailGunEmailClient implements EmailClient {
    public void sendConfirmationEmail(Application application, String recipientEmail);
    public void sendNextStepsEmail(Application application, String recipientEmail);
    public void sendDocumentUploadConfirmation(Application application);
    public void sendToCounty(Application application, String countyEmail, byte[] pdfAttachment);
}
```

**Configuration:**
```yaml
mail-gun:
  url: "https://api.mailgun.net/v3/mail.mnbenefits.mn.gov/messages"
  api-key: ${MAILGUN_API_KEY}
  sender-email: "help@mnbenefits.org"
  sender-name: "MN Benefits"
  security-email: "security@mnbenefits.org"
  audit-email: "audit@state.mn.us"
```

### Multi-State Abstraction

#### Proposed Interface
```java
public interface EmailService {
    /**
     * Send email with optional attachments
     */
    void sendEmail(EmailRequest request);

    /**
     * Send templated email (Thymeleaf)
     */
    void sendTemplatedEmail(String templateName, Map<String, Object> context, String to);
}

public class EmailRequest {
    private String from;
    private String fromName;
    private List<String> to;
    private List<String> cc;
    private List<String> bcc;
    private String subject;
    private String htmlBody;
    private String textBody;
    private List<Attachment> attachments;
}
```

#### Implementation Options

**Option A: Mailgun (Current)**
```java
@ConditionalOnProperty(name = "integrations.email_service.provider", havingValue = "mailgun")
public class MailgunEmailService implements EmailService { }
```

**Option B: SendGrid**
```java
@ConditionalOnProperty(name = "integrations.email_service.provider", havingValue = "sendgrid")
public class SendGridEmailService implements EmailService { }
```

**Option C: AWS SES**
```java
@ConditionalOnProperty(name = "integrations.email_service.provider", havingValue = "aws_ses")
public class AwsSesEmailService implements EmailService { }
```

**Option D: SMTP (Generic)**
```java
@ConditionalOnProperty(name = "integrations.email_service.provider", havingValue = "smtp")
public class SmtpEmailService implements EmailService {
    // Use Spring's JavaMailSender
    // Support state-specific SMTP servers
}
```

---

## 3. Address Validation Integration (SmartyStreets)

### Current Implementation

**File:** `/src/main/java/org/codeforamerica/shiba/pages/enrichment/smartystreets/SmartyStreetClient.java`

**Endpoint:** `https://us-street.api.smartystreets.com/street-address`

**Authentication:** Auth ID + Auth Token (query params)

**Operations:**
```java
public class SmartyStreetClient {
    public Optional<Address> validate(Address inputAddress) {
        // Call SmartyStreets API
        // Parse response
        // Return standardized address with county
    }
}
```

**Response:**
```json
{
  "delivery_line_1": "123 Main St",
  "last_line": "Minneapolis MN 55401-1234",
  "components": {
    "primary_number": "123",
    "street_name": "Main",
    "city_name": "Minneapolis",
    "state_abbreviation": "MN",
    "zipcode": "55401",
    "plus4_code": "1234"
  },
  "metadata": {
    "county_name": "Hennepin",
    "county_fips": "27053"
  }
}
```

### Multi-State Abstraction

#### Proposed Interface
```java
public interface AddressValidationService {
    /**
     * Validate and standardize address
     */
    Optional<ValidatedAddress> validate(Address inputAddress);

    /**
     * Determine county/region from address
     */
    Optional<String> determineRegion(Address address);
}

public class ValidatedAddress {
    private String street;
    private String city;
    private String state;
    private String zipCode;
    private String county;
    private String countyFips;
    private boolean isValid;
}
```

#### Implementation Options

**Option A: SmartyStreets (Current)**
```java
@ConditionalOnProperty(name = "integrations.address_validation.provider", havingValue = "smartystreets")
public class SmartyStreetsAddressValidationService implements AddressValidationService { }
```

**Option B: USPS (Free for US addresses)**
```java
@ConditionalOnProperty(name = "integrations.address_validation.provider", havingValue = "usps")
public class UspsAddressValidationService implements AddressValidationService { }
```

**Option C: Google Maps Geocoding API**
```java
@ConditionalOnProperty(name = "integrations.address_validation.provider", havingValue = "google")
public class GoogleAddressValidationService implements AddressValidationService { }
```

**Option D: No Validation (Fallback)**
```java
@ConditionalOnProperty(name = "integrations.address_validation.provider", havingValue = "none")
public class NoOpAddressValidationService implements AddressValidationService {
    // Accept address as-is
    // Use zip code mapping for county determination
}
```

---

## 4. Document Storage Integration (Azure Blob Storage)

### Current Implementation

**File:** `/src/main/java/org/codeforamerica/shiba/documents/AzureDocumentRepository.java`

**SDK:** Azure Storage Blob Java SDK

**Operations:**
```java
public class AzureDocumentRepository implements CloudDocumentRepository {
    public void upload(String filename, byte[] fileBytes);
    public byte[] download(String filename);
    public void delete(String filename);
}
```

**Configuration:**
```yaml
azure:
  blob:
    connection-string: ${AZURE_STORAGE_CONNECTION_STRING}
    container-name: "uploaded-documents"
```

### Multi-State Abstraction

#### Proposed Interface
```java
public interface DocumentStorageService {
    /**
     * Upload document
     */
    void upload(String documentId, String filename, InputStream inputStream, long size);

    /**
     * Download document
     */
    InputStream download(String documentId);

    /**
     * Delete document
     */
    void delete(String documentId);

    /**
     * Generate temporary download URL (for direct access)
     */
    String generateDownloadUrl(String documentId, Duration validity);
}
```

#### Implementation Options

**Option A: Azure Blob Storage (Current)**
```java
@ConditionalOnProperty(name = "integrations.document_storage.provider", havingValue = "azure_blob")
public class AzureBlobDocumentStorageService implements DocumentStorageService { }
```

**Option B: AWS S3**
```java
@ConditionalOnProperty(name = "integrations.document_storage.provider", havingValue = "aws_s3")
public class S3DocumentStorageService implements DocumentStorageService { }
```

**Option C: Google Cloud Storage**
```java
@ConditionalOnProperty(name = "integrations.document_storage.provider", havingValue = "gcs")
public class GcsDocumentStorageService implements DocumentStorageService { }
```

**Option D: Local File System (Dev/Small States)**
```java
@ConditionalOnProperty(name = "integrations.document_storage.provider", havingValue = "local_filesystem")
public class LocalFileSystemDocumentStorageService implements DocumentStorageService { }
```

**Option E: MinIO (Self-hosted S3-compatible)**
```java
@ConditionalOnProperty(name = "integrations.document_storage.provider", havingValue = "minio")
public class MinioDocumentStorageService implements DocumentStorageService { }
```

---

## 5. Analytics Integration (Mixpanel)

### Current Implementation

**File:** `/src/main/java/org/codeforamerica/shiba/pages/events/MixpanelInteractionTracker.java`

**SDK:** Mixpanel Java SDK

**Events Tracked:**
- Page views
- Form submissions
- Document uploads
- Application submissions
- Errors

**Configuration:**
```yaml
mixpanel:
  api-token: ${MIXPANEL_TOKEN}
```

### Multi-State Abstraction

#### Proposed Interface
```java
public interface AnalyticsService {
    /**
     * Track user interaction event
     */
    void trackEvent(String eventName, Map<String, Object> properties);

    /**
     * Identify user (for authenticated users)
     */
    void identifyUser(String userId, Map<String, Object> userProperties);
}
```

#### Implementation Options

**Option A: Mixpanel (Current)**
```java
@ConditionalOnProperty(name = "integrations.analytics.provider", havingValue = "mixpanel")
public class MixpanelAnalyticsService implements AnalyticsService { }
```

**Option B: Google Analytics 4**
```java
@ConditionalOnProperty(name = "integrations.analytics.provider", havingValue = "google_analytics")
public class GoogleAnalyticsService implements AnalyticsService { }
```

**Option C: Matomo (Open Source, Self-hosted)**
```java
@ConditionalOnProperty(name = "integrations.analytics.provider", havingValue = "matomo")
public class MatomoAnalyticsService implements AnalyticsService { }
```

**Option D: No Analytics**
```java
@ConditionalOnProperty(name = "integrations.analytics.provider", havingValue = "none")
public class NoOpAnalyticsService implements AnalyticsService { }
```

---

## 6. Error Tracking Integration (Sentry)

### Current Implementation

**SDK:** Sentry Spring Boot Starter

**Configuration:**
```yaml
sentry:
  dsn: ${SENTRY_DSN}
  environment: production
```

**Auto-captured:**
- Exceptions
- HTTP errors
- Performance metrics

### Multi-State Abstraction

#### Proposed Interface
```java
public interface ErrorTrackingService {
    /**
     * Capture exception
     */
    void captureException(Throwable throwable, Map<String, String> context);

    /**
     * Capture message
     */
    void captureMessage(String message, SeverityLevel level);

    /**
     * Set user context
     */
    void setUserContext(String userId, Map<String, String> userData);
}
```

#### Implementation Options

**Option A: Sentry (Current)**
```java
@ConditionalOnProperty(name = "integrations.error_tracking.provider", havingValue = "sentry")
public class SentryErrorTrackingService implements ErrorTrackingService { }
```

**Option B: Rollbar**
```java
@ConditionalOnProperty(name = "integrations.error_tracking.provider", havingValue = "rollbar")
public class RollbarErrorTrackingService implements ErrorTrackingService { }
```

**Option C: Logging Only (No external service)**
```java
@ConditionalOnProperty(name = "integrations.error_tracking.provider", havingValue = "logging")
public class LoggingErrorTrackingService implements ErrorTrackingService {
    // Just log errors, no external service
}
```

---

## Integration Configuration Schema

### Proposed YAML Structure

```yaml
# /src/main/resources/states/{state}/integrations.yaml

integrations:
  # Document submission to state system
  document_submission:
    provider: "soap_api"  # soap_api | rest_api | sftp | email | hybrid
    enabled: true

    soap_api:
      endpoint: "https://api.state.example.gov/DocumentService"
      wsdl: "https://api.state.example.gov/DocumentService?wsdl"
      namespace: "http://state.example.gov/documents"
      auth:
        type: "basic"  # basic | certificate | oauth2
        username: ${STATE_API_USERNAME}
        password: ${STATE_API_PASSWORD}
      retry:
        enabled: true
        max_attempts: 3
        backoff_strategy: "exponential"
        initial_delay_minutes: 90
        max_delay_minutes: 180
      mapping:
        # Map internal document types to state-specific types
        CAF: "BenefitsApplication"
        CCAP: "ChildCareApplication"
        UPLOADED_DOC: "SupportingDocument"

    rest_api:
      base_url: "https://api.state.example.gov/v1"
      auth:
        type: "oauth2_client_credentials"
        token_url: "https://auth.state.example.gov/token"
        client_id: ${API_CLIENT_ID}
        client_secret: ${API_CLIENT_SECRET}
      endpoints:
        submit: "/applications"
        status: "/applications/{id}/status"
      headers:
        X-State-Agency: "DHS"

  # Email service
  email_service:
    provider: "mailgun"  # mailgun | sendgrid | aws_ses | smtp
    enabled: true

    mailgun:
      api_key: ${MAILGUN_API_KEY}
      domain: "mail.benefits.state.example.gov"
      region: "us"  # us | eu
      from_address: "help@benefits.state.example.gov"
      from_name: "State Benefits"

    smtp:
      host: "smtp.state.example.gov"
      port: 587
      username: ${SMTP_USERNAME}
      password: ${SMTP_PASSWORD}
      tls_enabled: true
      from_address: "noreply@state.example.gov"

  # Address validation
  address_validation:
    provider: "smartystreets"  # smartystreets | usps | google | none
    enabled: true

    smartystreets:
      auth_id: ${SMARTYSTREETS_AUTH_ID}
      auth_token: ${SMARTYSTREETS_AUTH_TOKEN}
      license_type: "us-core-cloud"

    usps:
      user_id: ${USPS_USER_ID}

  # Document storage
  document_storage:
    provider: "azure_blob"  # azure_blob | aws_s3 | gcs | minio | local_filesystem
    enabled: true

    azure_blob:
      connection_string: ${AZURE_STORAGE_CONNECTION_STRING}
      container_name: "uploaded-documents"

    aws_s3:
      region: "us-east-1"
      bucket_name: "state-benefits-documents"
      access_key: ${AWS_ACCESS_KEY}
      secret_key: ${AWS_SECRET_KEY}

  # Analytics
  analytics:
    provider: "mixpanel"  # mixpanel | google_analytics | matomo | none
    enabled: true

    mixpanel:
      token: ${MIXPANEL_TOKEN}
      project_name: "State Benefits Application"

  # Error tracking
  error_tracking:
    provider: "sentry"  # sentry | rollbar | logging | none
    enabled: true

    sentry:
      dsn: ${SENTRY_DSN}
      environment: "production"
      traces_sample_rate: 0.1
```

---

## Integration Health Checks

### Proposed Health Check Endpoints

```java
@Component
public class IntegrationsHealthIndicator implements HealthIndicator {
    @Override
    public Health health() {
        return Health.up()
            .withDetail("document_submission", checkDocumentSubmission())
            .withDetail("email_service", checkEmailService())
            .withDetail("address_validation", checkAddressValidation())
            .withDetail("document_storage", checkDocumentStorage())
            .build();
    }
}
```

**Endpoint:** `GET /actuator/health`

**Response:**
```json
{
  "status": "UP",
  "components": {
    "integrations": {
      "status": "UP",
      "details": {
        "document_submission": "UP",
        "email_service": "UP",
        "address_validation": "UP",
        "document_storage": "UP"
      }
    }
  }
}
```

---

## Testing Strategy for Integrations

### 1. WireMock for Development
Mock external APIs during local development:
```java
@Test
public void testDocumentSubmission_withWireMock() {
    stubFor(post(urlEqualTo("/DocumentService"))
        .willReturn(aResponse()
            .withStatus(200)
            .withBody("<Success>true</Success>")));

    // Test submission
}
```

### 2. Integration Test Profiles
```yaml
# application-integration-test.yaml
integrations:
  document_submission:
    provider: "mock"  # Use mock implementation
  email_service:
    provider: "mock"
```

### 3. Sandbox Environments
States should provide sandbox/test endpoints for integration testing.

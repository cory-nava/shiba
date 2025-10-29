# API Endpoints & Routes

## Architecture Style
**Primary Pattern:** Server-Side Rendered (SSR) with RESTful endpoints
**Template Engine:** Thymeleaf
**HTTP Client:** Spring WebFlux WebClient (for external APIs)

## Public Endpoints (Citizen-Facing)

### Application Flow Endpoints

#### 1. Landing & Getting Started
```
GET /
  └─ Landing page, program selection

GET /pages/{pageName}
  └─ Display form page
  └─ Controller: PageController.java
  └─ Template: /templates/{pageName}.html
  └─ Parameters: None
  └─ Returns: HTML form page

POST /pages/{pageName}
  └─ Submit form page and navigate to next
  └─ Controller: PageController.java
  └─ Parameters: Form data (multipart/form-data or application/x-www-form-urlencoded)
  └─ Returns: Redirect to next page or validation errors
```

#### 2. File Upload
```
POST /pages/{pageName}/uploadFile
  └─ Upload documents (PDF, JPG, PNG)
  └─ Controller: PageController.java:uploadFile()
  └─ Parameters:
      - file: MultipartFile
      - dataURL: String (optional, for camera captures)
      - thumbDataURL: String (thumbnail)
      - doc_type: String (document classification)
  └─ Max Size: 10MB per file
  └─ Returns: JSON success/error response
  └─ Storage: Azure Blob Storage

DELETE /pages/{pageName}/deleteFile
  └─ Delete uploaded document
  └─ Controller: PageController.java:deleteFile()
  └─ Parameters:
      - filename: String
  └─ Returns: JSON success response
```

#### 3. Application Submission
```
POST /submit
  └─ Final application submission
  └─ Controller: PageController.java:submit()
  └─ Side Effects:
      - Saves application to database
      - Triggers ApplicationSubmittedEvent
      - Generates PDFs (CAF, CCAP, XML)
      - Sends to MNIT FileNet
      - Sends confirmation email
  └─ Returns: Redirect to confirmation page

GET /confirmation/{applicationId}
  └─ Confirmation page after submission
  └─ Shows application ID, next steps
```

#### 4. Document Download
```
GET /download/{applicationId}
  └─ Download submitted application PDF
  └─ Controller: FileDownloadController.java
  └─ Auth: Requires matching session or admin access
  └─ Parameters:
      - applicationId: String
      - type: String (CAF, CCAP, UPLOADED_DOCS)
  └─ Returns: application/pdf
```

### Navigation & Utility
```
GET /pages/navigation/goBack
  └─ Navigate to previous page
  └─ Uses session navigation history

POST /pages/navigation/skip
  └─ Skip optional page
  └─ Parameters: skippedPageName

GET /errorTimeout
  └─ Session timeout error page

GET /error
  └─ General error page
  └─ Parameters: error (error message)
```

### Feedback
```
POST /submit-feedback
  └─ Submit application feedback
  └─ Parameters:
      - sentiment: HAPPY | MEH | SAD
      - feedback: String (optional)
  └─ Updates application record
```

## Admin Endpoints (State Staff)

### Email Management
```
POST /resend-confirmation-email/{applicationId}
  └─ Resend confirmation email to applicant
  └─ Auth: Admin emails only
  └─ Controller: ResendFailedEmailController.java
  └─ Parameters: applicationId
  └─ Returns: Success/failure message

POST /resend-next-steps-email/{applicationId}
  └─ Resend next steps email
  └─ Auth: Admin emails only
```

### Application Access
```
GET /download-caf/{applicationId}
  └─ Download CAF PDF
  └─ Auth: Admin emails only

GET /download-ccap/{applicationId}
  └─ Download CCAP PDF
  └─ Auth: Admin emails only
```

## OAuth2 Authentication Endpoints

### Login
```
GET /oauth2/authorization/google
  └─ Redirect to Google OAuth login
  └─ Used for testing/development

GET /oauth2/authorization/azure-active-directory
  └─ Redirect to Azure AD login
  └─ Used for Minnesota state staff

GET /login
  └─ Login page (if not authenticated)

POST /logout
  └─ Logout and clear session
```

## Internal/System Endpoints

### Health & Monitoring
```
GET /actuator/health
  └─ Application health check
  └─ Returns: {"status": "UP"}

GET /actuator/info
  └─ Application information
```

## External API Integrations (Outbound)

### 1. MNIT FileNet (SOAP)
**Endpoint:** `https://test-svcs.dhs.mn.gov/WebServices/FileNet/ObjectService/SOAP`
**Protocol:** SOAP 1.1
**Client:** FilenetWebServiceClient.java

```xml
POST /WebServices/FileNet/ObjectService/SOAP
  Content-Type: text/xml; charset=utf-8
  SOAPAction: "http://tempuri.org/IObjectService/UploadDocument"

  Request Body:
    <soapenv:Envelope>
      <soapenv:Body>
        <tem:UploadDocument>
          <tem:documentRequest>
            <tem:DocumentClass>CAF | CCAP | ...</tem:DocumentClass>
            <tem:DocumentContent>[Base64 PDF]</tem:DocumentContent>
            <tem:County>Hennepin</tem:County>
            <tem:ApplicationId>uuid</tem:ApplicationId>
            <!-- Additional metadata -->
          </tem:DocumentRequest>
        </tem:UploadDocument>
      </soapenv:Body>
    </soapenv:Envelope>

  Response:
    <UploadDocumentResult>
      <Success>true</Success>
      <DocumentId>12345</DocumentId>
    </UploadDocumentResult>
```

### 2. Mailgun Email API
**Endpoint:** `https://api.mailgun.net/v3/mail.mnbenefits.mn.gov/messages`
**Protocol:** REST
**Client:** MailGunEmailClient.java

```
POST /v3/mail.mnbenefits.mn.gov/messages
  Authorization: Basic [API_KEY]
  Content-Type: multipart/form-data

  Parameters:
    - from: "help@mnbenefits.org"
    - to: "applicant@example.com"
    - subject: "Your application has been submitted"
    - html: "<html>...</html>"
    - cc: (optional, production only)

  Response:
    {
      "id": "<message-id@mail.mnbenefits.mn.gov>",
      "message": "Queued. Thank you."
    }
```

### 3. SmartyStreets Address Validation
**Endpoint:** `https://us-street.api.smartystreets.com/street-address`
**Protocol:** REST (GET)
**Client:** SmartyStreetClient.java

```
GET /street-address
  Parameters:
    - auth-id: [AUTH_ID]
    - auth-token: [AUTH_TOKEN]
    - street: "123 Main St"
    - city: "Minneapolis"
    - state: "MN"
    - zipcode: "55401"

  Response:
    [
      {
        "delivery_line_1": "123 Main St",
        "last_line": "Minneapolis MN 55401-1234",
        "components": {
          "primary_number": "123",
          "street_name": "Main",
          "street_suffix": "St",
          "city_name": "Minneapolis",
          "state_abbreviation": "MN",
          "zipcode": "55401",
          "plus4_code": "1234"
        },
        "metadata": {
          "county_name": "Hennepin"
        }
      }
    ]
```

### 4. Azure Blob Storage
**SDK:** Azure Storage Blob Java SDK
**Client:** AzureDocumentRepository.java

```java
// Upload document
containerClient.getBlobClient(filename)
  .upload(inputStream, size, overwrite);

// Download document
blobClient.downloadStream(outputStream);

// List blobs
containerClient.listBlobs();
```

### 5. Mixpanel Analytics
**Endpoint:** `https://api.mixpanel.com/track`
**Protocol:** REST
**Client:** MixpanelInteractionTracker.java

```
POST /track
  Content-Type: application/json

  Body:
    {
      "event": "page_view",
      "properties": {
        "distinct_id": "session-id",
        "page": "personalInfo",
        "flow": "FULL",
        "county": "Hennepin"
      }
    }
```

## Page Flow Configuration

### pages-config.yaml Structure
**File:** `/src/main/resources/pages-config.yaml`

This YAML file defines:
- All pages in the application
- Page navigation (next page logic)
- Conditional page display (conditions)
- Subworkflow definitions (household, jobs, etc.)

```yaml
pages:
  - name: "landing"
    nextPages:
      - name: "languagePreferences"

  - name: "personalInfo"
    nextPages:
      - name: "contactInfo"
    conditionalNavigation:
      - condition: "hasHousehold"
        nextPage: "householdList"

subworkflows:
  household:
    entryPage: "householdMemberInfo"
    iterationPage: "householdList"
    reviewPage: "householdReview"
```

### Page Types
1. **Landing Pages** - Entry points
2. **Form Pages** - Data collection
3. **Subworkflow Entry** - Start repeated sections
4. **Subworkflow Iteration** - List/manage iterations
5. **Review Pages** - Confirm data
6. **Confirmation** - Final success page

## Error Handling

### HTTP Status Codes
- `200 OK` - Successful page load/submission
- `302 Found` - Redirect to next page
- `400 Bad Request` - Validation errors
- `401 Unauthorized` - Not authenticated
- `403 Forbidden` - Admin access required
- `404 Not Found` - Page/application not found
- `500 Internal Server Error` - System error

### Error Response Format
```html
<!-- Validation errors displayed in page -->
<div class="notice--error">
  <p>Please correct the following errors:</p>
  <ul>
    <li>First name is required</li>
    <li>Social Security Number is invalid</li>
  </ul>
</div>
```

## Rate Limiting & Security

### Session Management
- 60-minute timeout
- CSRF token required for POST requests
- Session stored in database (JDBC)

### File Upload Restrictions
- Max size: 10MB per file
- Allowed types: PDF, JPG, PNG, GIF, BMP, TIF
- Virus scanning: Not currently implemented (recommendation for enhancement)

### CORS
- Not applicable (same-origin, server-rendered)

## API Usage Patterns

### Synchronous Operations
- Page rendering
- Form validation
- Session management

### Asynchronous Operations (Events)
- Document submission to MNIT (ApplicationSubmittedEvent)
- Email sending (ApplicationSubmittedEvent)
- PDF generation
- Mixpanel tracking

### Retry Logic
**Service:** ResubmissionService.java
**Scheduled Tasks:**
```java
@Scheduled(cron = "0 0 */3 * * *") // Every 3 hours
void resubmitFailedApplications();

@Scheduled(cron = "0 0 */1 * * *") // Every 1 hour
void resubmitInProgressApplications();

@Scheduled(cron = "0 */10 * * * *") // Every 10 minutes
void resubmitApplicationsWithNoStatus();
```

**Backoff Strategy:**
- Initial delay: 1.5 hours
- Max delay: 3 hours
- Exponential backoff

## Multi-State API Considerations

### What Needs to Be Configurable:
1. **Document submission endpoints** - Replace MNIT FileNet with state-specific APIs
2. **Email service** - Replace Mailgun domain with state-specific
3. **Address validation** - May need state-specific service
4. **Document types** - Different states require different forms
5. **Routing logic** - County/region routing varies by state
6. **Authentication** - OAuth providers vary by state

### Recommended API Abstraction:
```java
// Interface for state-specific document submission
public interface DocumentSubmissionClient {
    SubmissionResult submitCAF(Application application, byte[] pdf);
    SubmissionResult submitCCAP(Application application, byte[] pdf);
    SubmissionResult submitDocuments(Application application, List<Document> docs);
}

// Implementations:
// - MinnesotaFilenetClient (current)
// - GenericRestApiClient (for REST-based states)
// - GenericSoapClient (for SOAP-based states)
// - SftpClient (for SFTP-based states)
// - EmailClient (for email-based routing)
```

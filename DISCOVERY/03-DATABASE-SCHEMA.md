# Database Schema

## Database Technology
- **RDBMS:** PostgreSQL 11+
- **Migration Tool:** Flyway
- **Migration Location:** `/src/main/resources/db/migration/`

## Core Tables

### 1. `application` Table
**Primary Entity:** Stores application submissions

**Columns:**
- `id` (VARCHAR, PRIMARY KEY) - UUID application identifier
- `completed_at` (TIMESTAMP) - When application was submitted
- `application_data` (JSONB) - Encrypted form data (see ApplicationData structure)
- `county` (VARCHAR) - Minnesota county enum value
- `time_to_complete` (BIGINT) - Seconds to complete application
- `flow` (VARCHAR) - Application flow type (FULL, LATER_DOCS, MINIMUM)
- `sentiment` (VARCHAR) - User feedback sentiment (HAPPY, MEH, SAD)
- `feedback` (TEXT) - User feedback text
- `doc_upload_email_status` (VARCHAR) - Status of document upload notification
- `caf_status` (VARCHAR) - CAF document delivery status
- `ccap_status` (VARCHAR) - CCAP document delivery status
- `xml_status` (VARCHAR) - XML metadata delivery status
- `uploaded_doc_status` (VARCHAR) - User-uploaded documents delivery status
- `certain_pops_status` (VARCHAR) - CERTAIN_POPS document delivery status

**Indexes:**
- Primary key on `id`
- Potentially on `completed_at` for queries

**Migrations:**
- V22: Added `application_data` JSONB column
- V27: Added CAF, CCAP, docs status columns
- V30: Added doc_upload_email_status

### 2. `spring_session` and `spring_session_attributes` Tables
**Purpose:** JDBC-backed HTTP sessions for stateful form navigation

**Spring Session Schema:**
- `primary_id` (VARCHAR) - Session ID
- `session_id` (VARCHAR) - Unique session identifier
- `creation_time` (BIGINT) - Session creation timestamp
- `last_access_time` (BIGINT) - Last activity timestamp
- `max_inactive_interval` (INT) - Timeout (3600 seconds = 60 minutes)
- `expiry_time` (BIGINT) - Expiration timestamp
- `principal_name` (VARCHAR) - Authenticated user (if any)

### 3. `shedlock` Table
**Purpose:** Distributed lock for scheduled task coordination

**Columns:**
- `name` (VARCHAR, PRIMARY KEY) - Lock name
- `lock_until` (TIMESTAMP) - Lock expiration
- `locked_at` (TIMESTAMP) - Lock acquisition time
- `locked_by` (VARCHAR) - Instance identifier

### 4. `metrics` Table (V1 migration)
**Purpose:** Application metrics and usage tracking

**Note:** Schema details would need to be reviewed in V1 migration file.

## Application Data JSONB Structure

The `application_data` column stores encrypted JSON with the following structure:

```json
{
  "pagesData": {
    "pageName": {
      "fieldName": {
        "value": ["string_value"],
        "type": "SINGLE_VALUE | ENUMERATED_SINGLE_VALUE | etc."
      }
    }
  },
  "subworkflows": {
    "household": [
      {
        "id": "uuid",
        "complete": true,
        "pages": { ... }
      }
    ],
    "jobs": [ ... ],
    "income": [ ... ]
  },
  "uploadedDocs": [
    {
      "filename": "document.pdf",
      "doc_type": "OTHER",
      "size": 123456,
      "uploadedAt": "2024-01-01T12:00:00Z"
    }
  ],
  "expeditedEligibility": {
    "SNAP": "ELIGIBLE | UNDETERMINED | NOT_ELIGIBLE",
    "CCAP": "..."
  },
  "startTimeOnce": "2024-01-01T12:00:00Z",
  "flow": "FULL | LATER_DOCS | MINIMUM"
}
```

### Pages Data Structure
**Java Class:** `/src/main/java/org/codeforamerica/shiba/application/pages/data/PagesData.java`

- Stores all form inputs by page name
- Each page contains fields (InputData)
- Field types: SINGLE_VALUE, MULTI_VALUE, DATE, PHONE, etc.

### Subworkflows
**Java Class:** `/src/main/java/org/codeforamerica/shiba/application/pages/data/Subworkflows.java`

Repeating sections for:
- **household** - Household members (name, DOB, SSN, relationship)
- **jobs** - Employment history
- **income** - Income sources
- **assets** - Financial assets
- **expenses** - Household expenses

Each iteration has:
- Unique UUID
- Complete status flag
- Own pages data

### Uploaded Documents
**Java Class:** `/src/main/java/org/codeforamerica/shiba/application/documents/UploadedDocument.java`

Metadata stored in application_data:
- Filename
- Document type (PROOF_OF_INCOME, PROOF_OF_HOUSING, OTHER, etc.)
- File size
- Upload timestamp

Actual files stored in Azure Blob Storage.

## Status Tracking

### Application Status Enum Values
**File:** `/src/main/java/org/codeforamerica/shiba/application/ApplicationStatusType.java`

- `SENDING` - Submitting to state system
- `DELIVERED` - Successfully delivered
- `DELIVERY_FAILED` - Failed delivery (will retry)
- `RESUBMISSION_FAILED` - Retry failed (manual intervention needed)

### Document Types Tracked
1. **CAF** - Common Application Form
2. **CCAP** - Child Care Assistance Program form
3. **XML** - XML metadata for ESB
4. **UPLOADED_DOC** - User-uploaded documents
5. **CERTAIN_POPS** - Minnesota CERTAIN_POPS program form

Each document type has its own status column.

## Encryption

### Encryption Method
**Library:** Google Tink (AES256_GCM)
**File:** `/src/main/java/org/codeforamerica/shiba/application/ApplicationDataEncryptor.java`

- `application_data` is encrypted before storage
- Encryption key from environment variable `ENCRYPTION_KEY`
- Decrypted on read for processing

### PII Masking
**File:** `/src/main/resources/personal-data-mappings.yaml`

For logging/debugging:
- SSN: `XXX-XX-XXXX`
- Other PII fields masked

## Queries & Access Patterns

### Common Queries

1. **Find failed applications (for resubmission):**
```sql
SELECT * FROM application
WHERE caf_status = 'DELIVERY_FAILED'
   OR ccap_status = 'DELIVERY_FAILED'
   OR uploaded_doc_status = 'DELIVERY_FAILED';
```

2. **Find in-progress submissions:**
```sql
SELECT * FROM application
WHERE caf_status = 'SENDING'
   OR ccap_status = 'SENDING';
```

3. **Applications by county:**
```sql
SELECT * FROM application
WHERE county = 'Hennepin'
ORDER BY completed_at DESC;
```

4. **Recent applications:**
```sql
SELECT id, completed_at, county, flow
FROM application
WHERE completed_at > NOW() - INTERVAL '7 days'
ORDER BY completed_at DESC;
```

### JSONB Queries

PostgreSQL JSONB allows querying encrypted data (after decryption in application layer):

```sql
-- Applications with specific program
SELECT * FROM application
WHERE application_data->'pagesData'->'choosePrograms'->'programs'->>'value'
LIKE '%SNAP%';
```

**Note:** Most JSONB queries happen in Java layer after decryption.

## Migration Strategy

### Flyway Migrations
**Location:** `/src/main/resources/db/migration/`

**Key Migrations:**
- `V1__*.sql` - Initial schema
- `V22__*.sql` - Added application_data JSONB
- `V27__*.sql` - Added status columns for document delivery
- `V30__*.sql` - Added doc_upload_email_status

**Migration Naming:** `V{version}__{description}.sql`

### Backwards Compatibility
- Application uses JPA/Hibernate
- Schema changes require careful migration planning
- Encrypted JSONB allows schema flexibility without migrations

## Performance Considerations

1. **JSONB Indexing:** Consider GIN indexes for JSONB queries if needed
2. **Session Cleanup:** Expired sessions cleaned up by Spring Session
3. **Status Queries:** Indexes on status columns for resubmission service
4. **Archive Strategy:** No current archival; consider for long-term storage

## Multi-State Adaptation Notes

### State-Agnostic Schema Changes Needed:
1. Replace `county` with flexible `region` or `routing_destination`
2. Make status columns configurable (different states = different doc types)
3. Add `state_code` column for multi-state support
4. Add `tenant_id` for true multi-tenancy
5. Externalize document type definitions
6. Make `flow` types configurable (different states may have different flows)

### What Can Stay:
- Core `application` table structure
- JSONB `application_data` (flexible schema)
- Session management
- Encryption approach
- Status tracking pattern (just make types configurable)

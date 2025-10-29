# State-Specific Logic (Minnesota)

## Hardcoded Minnesota Values

### Geographic Configuration

#### Counties
- **File:** `/src/main/java/org/codeforamerica/shiba/County.java`
- **Count:** 87 Minnesota counties (enum)
- **Mapping:** `/src/main/resources/zip-to-county-mapping.yaml`
- **Usage:** Routing applications to correct county office

#### Tribal Nations
- **File:** `/src/main/java/org/codeforamerica/shiba/TribalNation.java`
- **Count:** 11 Minnesota tribal nations
- **Configuration:** `/src/main/java/org/codeforamerica/shiba/mnit/TribalNationConfiguration.java`
- **Supported Nations:**
  - Mille Lacs Band of Ojibwe
  - White Earth Nation
  - Red Lake Nation
  - Fond du Lac Band of Lake Superior Chippewa
  - Grand Portage Band of Lake Superior Chippewa
  - Leech Lake Band of Ojibwe
  - Bois Forte Band of Chippewa
  - Upper Sioux Community
  - Lower Sioux Indian Community
  - Prairie Island Indian Community
  - Shakopee Mdewakanton Sioux Community

### Time Zone
- **Hardcoded:** `America/Chicago` (Central Time)
- **Location:** `PageController.java:103`
- **Impact:** All timestamps and date logic

### Email Configuration
- **Sender Domain:** `help@mnbenefits.org`
- **Mailgun Domain:** `mail.mnbenefits.mn.gov`
- **Security Email:** Hardcoded for reporting issues
- **Audit Email:** Hardcoded for compliance
- **Admin Emails:** 9 specific Minnesota state staff (hardcoded in SecurityConfiguration.java)

### Program Names (Minnesota-Specific)
1. **SNAP** - Supplemental Nutrition Assistance Program
2. **CASH** - General Assistance / Emergency Assistance
3. **CCAP** - Child Care Assistance Program
4. **GRH** - General Relief Housing
5. **EA** - Emergency Assistance
6. **CERTAIN_POPS** - Community Action Funds (Minnesota-specific program)

## State System Integrations

### MNIT FileNet/ESB
- **Purpose:** Document submission to Minnesota state benefits system
- **Protocol:** SOAP Web Services
- **Files:**
  - `/src/main/java/org/codeforamerica/shiba/mnit/FilenetWebServiceClient.java`
  - `/src/main/java/org/codeforamerica/shiba/mnit/MnitEsbWebServiceClient.java`
- **Endpoints:**
  - Test: `https://test-svcs.dhs.mn.gov/WebServices/FileNet/ObjectService/SOAP`
  - Production: (configured per environment)
- **Documents Sent:** CAF, CCAP, XML metadata, uploaded documents
- **Authentication:** Username/password (environment variables)

### SFTP Fallback
- **URL:** `/router/api/fileNetToSftp`
- **Purpose:** Secondary delivery method if FileNet fails
- **Document Format:** Base64-encoded PDFs with metadata

## Minnesota-Specific Business Rules

### Expedited Eligibility
- **File:** `/src/main/java/org/codeforamerica/shiba/application/parsers/`
- SNAP expedited benefits calculations based on Minnesota thresholds
- CCAP expedited processing rules

### Document Types
- **CAF (Common Application Form)** - Minnesota's standard benefits application
- **CCAP Form** - Minnesota's child care assistance form
- **XML Metadata** - Minnesota ESB-specific format

### Routing Logic
- Applications routed based on:
  1. County of residence
  2. Tribal nation membership (overrides county)
  3. Program type (CERTAIN_POPS uses special routing)
- Different email/fax destinations per environment (dev, demo, production)

## Configuration Files Requiring State Adaptation

### 1. County Mapping
**File:** `/src/main/resources/zip-to-county-mapping.yaml`
```yaml
55001: Hennepin
55002: Washington
# ... 87 total mappings
```

### 2. Tribal Nation Configuration
**File:** `/src/main/java/org/codeforamerica/shiba/mnit/TribalNationConfiguration.java`
- Email addresses per nation per environment
- Phone numbers
- Physical addresses

### 3. Application Configuration
**Files:** `/src/main/resources/application-{profile}.yaml`
- MNIT endpoints
- County routing destinations
- Email routing
- Feature flags (e.g., `white-earth-and-red-lake-routing`)

### 4. Admin Email Allowlist
**File:** `/src/main/java/org/codeforamerica/shiba/configurations/SecurityConfiguration.java`
```java
public static final List<String> ADMIN_EMAILS = List.of(
    "john.bisek@state.mn.us",
    "eric.m.johnson@state.mn.us",
    // ... 7 more
);
```

## Localization
- **i18n Support:** Yes (Thymeleaf templates)
- **Current Languages:** English (primary), Spanish, others
- **Location:** `/src/main/resources/messages.properties`
- **State-Specific Terms:** Program names, legal disclaimers, contact info

## Feature Flags (Minnesota-Specific)
- `submit-via-api` - Enable API submission to MNIT
- `certain-pops` - Enable Minnesota's CERTAIN_POPS program
- `white-earth-and-red-lake-routing` - Special routing for specific tribal nations

## Compliance & Legal
- **Privacy Policy:** Minnesota-specific
- **Terms of Service:** Minnesota-specific
- **Accessibility:** WCAG 2.1 AA compliance required by Minnesota
- **Language Access:** Minnesota Executive Order 14-14 compliance

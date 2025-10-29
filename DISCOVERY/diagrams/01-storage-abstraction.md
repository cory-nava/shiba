# Storage Service - Detailed Diagrams

## Storage Provider Selection Flow

```mermaid
flowchart TD
    Start[Application Startup]
    Start --> LoadConfig[Load Configuration]

    LoadConfig --> CheckProvider{Check STORAGE_PROVIDER}

    CheckProvider -->|aws_s3| CheckAWS{AWS Credentials?}
    CheckProvider -->|azure_blob| CheckAzure{Azure Connection String?}
    CheckProvider -->|gcs| CheckGCP{GCP Credentials?}
    CheckProvider -->|minio| CheckMinIO{MinIO Config?}
    CheckProvider -->|local_filesystem| CheckLocal{Base Path Exists?}
    CheckProvider -->|not set| DefaultProvider[Use Default for Cloud]

    CheckAWS -->|Yes| InitS3[Initialize S3StorageProvider]
    CheckAWS -->|No| ConfigError[Configuration Error]

    CheckAzure -->|Yes| InitAzure[Initialize AzureBlobStorageProvider]
    CheckAzure -->|No| ConfigError

    CheckGCP -->|Yes| InitGCP[Initialize GCSStorageProvider]
    CheckGCP -->|No| ConfigError

    CheckMinIO -->|Yes| InitMinIO[Initialize MinIOStorageProvider]
    CheckMinIO -->|No| ConfigError

    CheckLocal -->|Yes| InitLocal[Initialize LocalFileSystemProvider]
    CheckLocal -->|No| CreatePath{Create Path?}

    CreatePath -->|Success| InitLocal
    CreatePath -->|Fail| ConfigError

    DefaultProvider --> DetectCloud{Detect Cloud Environment}
    DetectCloud -->|AWS| InitS3
    DetectCloud -->|Azure| InitAzure
    DetectCloud -->|GCP| InitGCP
    DetectCloud -->|Unknown| InitLocal

    InitS3 --> HealthCheck[Health Check]
    InitAzure --> HealthCheck
    InitGCP --> HealthCheck
    InitMinIO --> HealthCheck
    InitLocal --> HealthCheck

    HealthCheck --> Test{Connection Test}
    Test -->|Pass| Ready[Storage Service Ready]
    Test -->|Fail| Startup Error[Startup Error]

    ConfigError --> Fail([Application Fails to Start])
    Startup Error --> Fail

    Ready --> RegisterBean[Register as Spring Bean]

    style CheckProvider fill:#fff3cd
    style DetectCloud fill:#d1ecf1
    style Ready fill:#d4edda
    style Fail fill:#f8d7da
```

## Document Upload Flow (Multi-Provider)

```mermaid
sequenceDiagram
    participant User
    participant Controller as PageController
    participant Service as StorageService
    participant Provider as Storage Provider
    participant Cloud as Cloud Storage
    participant DB as Database

    User->>Controller: POST /pages/uploadFile
    Note over User,Controller: Multipart form with file

    Controller->>Controller: Validate file<br/>(size, type, virus scan)

    alt Validation Fails
        Controller-->>User: 400 Bad Request
    else Validation Passes
        Controller->>Service: upload(key, stream, metadata)

        Note over Service: Key = {tenant}/{app_id}/{filename}
        Note over Service: Metadata = {doc_type, size, uploaded_by}

        Service->>Provider: upload(key, stream, size, metadata)

        alt AWS S3
            Provider->>Cloud: PutObject(bucket, key, body)
            Cloud-->>Provider: ETag, VersionId
        else Azure Blob
            Provider->>Cloud: Upload(blob, stream)
            Cloud-->>Provider: BlobContentInfo
        else GCS
            Provider->>Cloud: CreateFrom(blob, stream)
            Cloud-->>Provider: BlobInfo
        else MinIO
            Provider->>Cloud: PutObject(bucket, key, stream)
            Cloud-->>Provider: ObjectWriteResponse
        else Local FileSystem
            Provider->>Provider: Files.copy(stream, path)
            Note over Provider: Write to /var/shiba/documents/
        end

        Provider-->>Service: Success
        Service-->>Controller: Upload complete

        Controller->>DB: Save metadata<br/>(filename, size, storage_key)
        DB-->>Controller: Saved

        Controller-->>User: 200 OK<br/>{"success": true, "filename": "..."}
    end
```

## Document Download Flow with Presigned URLs

```mermaid
sequenceDiagram
    participant User
    participant Controller as FileDownloadController
    participant Service as StorageService
    participant Provider as Storage Provider
    participant Cloud as Cloud Storage

    User->>Controller: GET /download/{applicationId}
    Controller->>Controller: Authorize user<br/>(own app or admin)

    alt Not Authorized
        Controller-->>User: 403 Forbidden
    else Authorized
        Controller->>DB: Get file key for application
        DB-->>Controller: storage_key

        Controller->>Service: download(storage_key)
        Service->>Provider: Check if presigned URLs supported

        alt Provider Supports Presigned URLs (S3, Azure, GCS, MinIO)
            Provider->>Cloud: Generate presigned URL<br/>(expires in 5 minutes)
            Cloud-->>Provider: Temporary URL
            Provider-->>Service: URL
            Service-->>Controller: Redirect URL
            Controller-->>User: 302 Redirect to presigned URL
            User->>Cloud: Direct download (no app involved)
            Cloud-->>User: File bytes
        else Provider Doesn't Support (Local FileSystem)
            Provider->>Provider: Open file stream
            Provider-->>Service: InputStream
            Service-->>Controller: Stream
            Controller-->>User: 200 OK<br/>Stream file bytes
        end
    end
```

## Storage Migration Tool

```mermaid
flowchart TD
    Start([Start Migration])
    Start --> Config[Load Source & Target Config]

    Config --> SourceInit[Initialize Source Provider<br/>e.g., Azure Blob]
    Config --> TargetInit[Initialize Target Provider<br/>e.g., AWS S3]

    SourceInit --> List[List all objects in source]
    List --> HasMore{More objects?}

    HasMore -->|Yes| GetNext[Get next batch<br/>100 objects]
    HasMore -->|No| Complete

    GetNext --> ProcessBatch[Process batch]

    ProcessBatch --> DownloadLoop{For each object}

    DownloadLoop --> Download[Download from source]
    Download --> Upload[Upload to target]
    Upload --> Verify{Verify checksums match?}

    Verify -->|Yes| UpdateDB[Update DB with new key]
    Verify -->|No| Retry{Retry count < 3?}

    Retry -->|Yes| Download
    Retry -->|No| LogError[Log error for manual review]

    UpdateDB --> NextObject[Next object]
    LogError --> NextObject
    NextObject --> DownloadLoop

    DownloadLoop -->|Batch complete| HasMore

    Complete([Migration Complete])
    Complete --> Report[Generate migration report]

    style Complete fill:#d4edda
    style LogError fill:#f8d7da
    style Verify fill:#fff3cd
```

## Storage Cost Comparison

```mermaid
graph LR
    subgraph "Storage Providers - Cost per GB/month"
        S3[AWS S3<br/>$0.023]
        S3IA[AWS S3-IA<br/>$0.0125]
        Azure[Azure Blob Hot<br/>$0.0208]
        AzureCool[Azure Blob Cool<br/>$0.01]
        GCS[GCS Standard<br/>$0.020]
        GCSNearline[GCS Nearline<br/>$0.010]
        MinIO[MinIO Self-Hosted<br/>Hardware cost only]
        Local[Local FileSystem<br/>Hardware cost only]
    end

    subgraph "Retrieval Costs"
        S3Retrieval[S3: $0.0004/1000 requests]
        AzureRetrieval[Azure: $0.0004/10000 requests]
        GCSRetrieval[GCS: $0.0004/10000 requests]
        SelfRetrieval[Self-Hosted: $0]
    end

    subgraph "Bandwidth Costs"
        S3Bandwidth[S3: $0.09/GB out]
        AzureBandwidth[Azure: $0.087/GB out]
        GCSBandwidth[GCS: $0.12/GB out]
        SelfBandwidth[Self-Hosted: $0*]
    end

    style S3IA fill:#d4edda
    style AzureCool fill:#d4edda
    style GCSNearline fill:#d4edda
    style MinIO fill:#d4edda
    style Local fill:#d4edda
    style SelfRetrieval fill:#d4edda
    style SelfBandwidth fill:#d4edda
```

## Recommended Storage Strategy by State Size

```mermaid
graph TB
    StateSize{State Size & Budget}

    StateSize -->|Small State<br/>< 1M population<br/>Low budget| SmallState
    StateSize -->|Medium State<br/>1-5M population<br/>Moderate budget| MediumState
    StateSize -->|Large State<br/>> 5M population<br/>Higher budget| LargeState

    subgraph SmallState[Small State Recommendation]
        SS1[Provider: Local FileSystem or MinIO]
        SS2[Cost: ~$100-500/month<br/>self-hosted storage]
        SS3[Pros: Simple, low cost, full control]
        SS4[Cons: Manual backups, limited scaling]
    end

    subgraph MediumState[Medium State Recommendation]
        MS1[Provider: AWS S3 or Azure Blob]
        MS2[Cost: ~$500-2000/month<br/>managed service]
        MS3[Lifecycle: Hot → Cool after 90 days]
        MS4[Pros: Managed, scalable, reliable]
    end

    subgraph LargeState[Large State Recommendation]
        LS1[Provider: AWS S3 with Intelligent Tiering]
        LS2[Cost: ~$2000-10000/month<br/>optimized for access patterns]
        LS3[Features: CDN, multi-region, versioning]
        LS4[Pros: Enterprise-grade, auto-optimization]
    end

    style SmallState fill:#d4edda
    style MediumState fill:#d1ecf1
    style LargeState fill:#fff3cd
```

## Storage Lifecycle Policy Example

```mermaid
flowchart LR
    Upload[Document Uploaded<br/>Hot Storage]

    Upload -->|After 30 days| Warm[Move to Warm Tier<br/>Infrequent Access]
    Warm -->|After 90 days| Cool[Move to Cool Tier<br/>Archive]
    Cool -->|After 7 years| Delete[Delete<br/>Retention period ended]

    Upload -.->|If accessed| StayHot[Stay in Hot]
    Warm -.->|If accessed| BackToHot[Back to Hot]

    subgraph "Storage Costs"
        Hot[Hot: $0.023/GB]
        WarmTier[Warm: $0.0125/GB]
        CoolTier[Cool: $0.004/GB]
    end

    Upload --> Hot
    Warm --> WarmTier
    Cool --> CoolTier

    style Upload fill:#fff3cd
    style Delete fill:#f8d7da
    style Hot fill:#f8d7da
    style WarmTier fill:#fff3cd
    style CoolTier fill:#d4edda
```

## Disaster Recovery - Storage Replication

```mermaid
graph TB
    subgraph "Primary Region"
        PrimaryStorage[Primary Storage<br/>AWS S3 us-east-1]
    end

    subgraph "Secondary Region"
        SecondaryStorage[Secondary Storage<br/>AWS S3 us-west-2]
    end

    subgraph "Backup"
        Glacier[AWS Glacier<br/>Long-term Archive]
    end

    PrimaryStorage -->|Cross-Region Replication<br/>Automatic| SecondaryStorage
    PrimaryStorage -->|Lifecycle Policy<br/>After 90 days| Glacier

    DR{Disaster in Primary Region?}
    DR -->|Yes| Failover[Failover to Secondary]
    DR -->|No| Normal[Continue Normal Ops]

    Failover --> SecondaryStorage
    Normal --> PrimaryStorage

    subgraph "RPO/RTO"
        RPO[RPO: < 15 minutes<br/>Recovery Point Objective]
        RTO[RTO: < 1 hour<br/>Recovery Time Objective]
    end

    style DR fill:#f8d7da
    style Failover fill:#fff3cd
    style Glacier fill:#d1ecf1
```

## Storage Security - Encryption at Rest

```mermaid
flowchart TD
    Upload[File Upload]

    Upload --> EncryptApp{Application-Level Encryption?}

    EncryptApp -->|Yes| AppEncrypt[Encrypt with AES-256<br/>before upload]
    EncryptApp -->|No| NoAppEncrypt[Upload plaintext]

    AppEncrypt --> StorageEncrypt{Storage-Level Encryption?}
    NoAppEncrypt --> StorageEncrypt

    StorageEncrypt -->|AWS S3| S3KMS[S3-SSE with KMS<br/>AES-256]
    StorageEncrypt -->|Azure Blob| AzureKV[Azure Storage Service Encryption<br/>with Key Vault]
    StorageEncrypt -->|GCS| GCSKMS[GCS with Cloud KMS]
    StorageEncrypt -->|Self-Hosted| SelfEncrypt[LUKS or ZFS encryption]

    S3KMS --> Store[(Encrypted Storage)]
    AzureKV --> Store
    GCSKMS --> Store
    SelfEncrypt --> Store

    Store --> Download[Download Request]

    Download --> StorageDecrypt[Storage auto-decrypts<br/>transparent to app]
    StorageDecrypt --> AppDecrypt{Application Encryption?}

    AppDecrypt -->|Yes| DecryptApp[Decrypt with app key]
    AppDecrypt -->|No| ReturnFile[Return file]

    DecryptApp --> ReturnFile
    ReturnFile --> User[User receives file]

    style AppEncrypt fill:#d4edda
    style Store fill:#d4edda
    style DecryptApp fill:#d4edda
```

This provides comprehensive visual documentation for the storage abstraction layer!

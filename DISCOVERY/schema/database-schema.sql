-- Complete Database Schema for SHIBA Application
-- Extracted from Flyway migrations and application code
-- PostgreSQL 11+

-- ================================================================
-- Core Application Table
-- ================================================================

CREATE TABLE applications (
    -- Primary key
    id VARCHAR NOT NULL PRIMARY KEY,

    -- Timestamps
    completed_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,

    -- Application data (encrypted JSONB containing all form data)
    application_data JSONB NOT NULL,

    -- Geographic routing
    county VARCHAR,  -- Minnesota county enum value

    -- Metadata
    time_to_complete BIGINT,  -- Time in seconds to complete application
    flow VARCHAR,  -- FULL, LATER_DOCS, MINIMUM

    -- User feedback
    sentiment VARCHAR,  -- HAPPY, MEH, SAD
    feedback TEXT,

    -- Email status
    doc_upload_email_status VARCHAR,

    -- Document delivery status (legacy - see application_status table)
    caf_status VARCHAR,
    ccap_status VARCHAR,
    xml_status VARCHAR,
    uploaded_doc_status VARCHAR,
    certain_pops_status VARCHAR
);

-- ================================================================
-- Application Status Tracking (Document Delivery)
-- ================================================================

CREATE TABLE application_status (
    application_id VARCHAR NOT NULL,
    document_type VARCHAR NOT NULL,  -- CAF, CCAP, XML, UPLOADED_DOC, CERTAIN_POPS
    routing_destination VARCHAR,  -- County, tribal nation, or special destination
    status VARCHAR NOT NULL,  -- SENDING, DELIVERED, DELIVERY_FAILED, RESUBMISSION_FAILED

    -- Timestamps
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

CREATE INDEX application_status_index
    ON application_status (application_id, document_type, routing_destination);

-- Auto-update timestamp trigger
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_timestamp_on_application_status
    BEFORE UPDATE ON application_status
    FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

-- ================================================================
-- Application Audit Log
-- ================================================================

CREATE TABLE applications_audit (
    id SERIAL PRIMARY KEY,
    application_id VARCHAR NOT NULL,
    operation VARCHAR NOT NULL,  -- INSERT, UPDATE, DELETE
    changed_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    changed_by VARCHAR,
    old_data JSONB,
    new_data JSONB
);

CREATE INDEX applications_audit_application_id_index
    ON applications_audit (application_id);

-- Audit trigger
CREATE TRIGGER applications_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON applications
    FOR EACH ROW
EXECUTE PROCEDURE audit_applications();

-- ================================================================
-- Spring Session Tables (JDBC Session Store)
-- ================================================================

CREATE TABLE spring_session (
    primary_id CHAR(36) NOT NULL,
    session_id CHAR(36) NOT NULL,
    creation_time BIGINT NOT NULL,
    last_access_time BIGINT NOT NULL,
    max_inactive_interval INT NOT NULL,
    expiry_time BIGINT NOT NULL,
    principal_name VARCHAR(100),

    CONSTRAINT spring_session_pk PRIMARY KEY (primary_id)
);

CREATE UNIQUE INDEX spring_session_ix1 ON spring_session (session_id);
CREATE INDEX spring_session_ix2 ON spring_session (expiry_time);
CREATE INDEX spring_session_ix3 ON spring_session (principal_name);

CREATE TABLE spring_session_attributes (
    session_primary_id CHAR(36) NOT NULL,
    attribute_name VARCHAR(200) NOT NULL,
    attribute_bytes BYTEA NOT NULL,

    CONSTRAINT spring_session_attributes_pk PRIMARY KEY (session_primary_id, attribute_name),
    CONSTRAINT spring_session_attributes_fk FOREIGN KEY (session_primary_id)
        REFERENCES spring_session(primary_id) ON DELETE CASCADE
);

-- ================================================================
-- Distributed Lock Table (ShedLock)
-- ================================================================

CREATE TABLE shedlock (
    name VARCHAR(64) NOT NULL,
    lock_until TIMESTAMP NOT NULL,
    locked_at TIMESTAMP NOT NULL,
    locked_by VARCHAR(255) NOT NULL,

    PRIMARY KEY (name)
);

-- ================================================================
-- Application ID Sequence
-- ================================================================

CREATE SEQUENCE application_id_seq START WITH 1 INCREMENT BY 1;

-- ================================================================
-- Sample Queries
-- ================================================================

-- Find applications by status
-- SELECT * FROM applications a
-- JOIN application_status s ON a.id = s.application_id
-- WHERE s.status = 'DELIVERY_FAILED';

-- Recent applications
-- SELECT id, completed_at, county, flow
-- FROM applications
-- WHERE completed_at > NOW() - INTERVAL '7 days'
-- ORDER BY completed_at DESC;

-- Application metrics
-- SELECT
--   county,
--   COUNT(*) as total_apps,
--   AVG(time_to_complete) as avg_time_seconds
-- FROM applications
-- WHERE completed_at > NOW() - INTERVAL '30 days'
-- GROUP BY county
-- ORDER BY total_apps DESC;

-- ================================================================
-- Notes for Multi-State Adaptation
-- ================================================================

-- 1. Add state_code or tenant_id column to applications table
-- ALTER TABLE applications ADD COLUMN state_code VARCHAR(2);
-- ALTER TABLE applications ADD COLUMN tenant_id VARCHAR;

-- 2. Replace county column with flexible region_code
-- ALTER TABLE applications RENAME COLUMN county TO region_code;

-- 3. Make document types configurable per state
--    Current: hardcoded CAF, CCAP, etc.
--    Future: reference document_types configuration table

-- 4. Add multi-tenancy support
-- CREATE TABLE tenants (
--     id VARCHAR PRIMARY KEY,
--     state_code VARCHAR(2),
--     name VARCHAR,
--     timezone VARCHAR,
--     config JSONB
-- );

-- CREATE TABLE regions (
--     id VARCHAR PRIMARY KEY,
--     tenant_id VARCHAR REFERENCES tenants(id),
--     code VARCHAR,
--     name VARCHAR,
--     routing_config JSONB
-- );

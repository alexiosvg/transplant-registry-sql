-- =============================================================
-- Schema for a small synthetic stem cell transplant registry
-- =============================================================
-- Six linked tables. Each table has a PRIMARY KEY (a unique ID
-- for every row), and tables are connected through FOREIGN KEYS
-- (a column that points to the primary key of another table).
--
--   centers ─< patients ─< diagnoses
--      │           │
--      └────< transplants >──── donors
--                  │
--                  └──< follow_ups
--
-- "─<" means one-to-many: one center has many patients,
-- one patient can have many diagnoses and transplants, etc.
--
-- Two further tables support data quality work:
--
--   dq_checks ─< dq_issues
--
-- dq_checks lists the checks, and dq_issues logs every record
-- flagged by a check so it can be followed up with the center.
-- =============================================================

PRAGMA foreign_keys = ON;   -- SQLite only enforces foreign keys when this is on

DROP VIEW  IF EXISTS dq_issue_details;
DROP TABLE IF EXISTS dq_issues;
DROP TABLE IF EXISTS dq_checks;
DROP TABLE IF EXISTS follow_ups;
DROP TABLE IF EXISTS transplants;
DROP TABLE IF EXISTS donors;
DROP TABLE IF EXISTS diagnoses;
DROP TABLE IF EXISTS patients;
DROP TABLE IF EXISTS centers;

-- Transplant centers (hospitals reporting to the registry)
CREATE TABLE centers (
    center_id   INTEGER PRIMARY KEY,
    center_name TEXT    NOT NULL,
    country     TEXT    NOT NULL
);

-- One row per patient
CREATE TABLE patients (
    patient_id        INTEGER PRIMARY KEY,
    center_id         INTEGER NOT NULL REFERENCES centers(center_id),
    sex               TEXT    CHECK (sex IN ('M', 'F')),   -- NULL allowed = unknown
    birth_date        TEXT    NOT NULL,                     -- ISO format YYYY-MM-DD
    registration_date TEXT    NOT NULL
);

-- Diagnoses, coded with ICD-10
CREATE TABLE diagnoses (
    diagnosis_id   INTEGER PRIMARY KEY,
    patient_id     INTEGER NOT NULL REFERENCES patients(patient_id),
    icd10_code     TEXT    NOT NULL,
    disease_name   TEXT    NOT NULL,
    diagnosis_date TEXT    NOT NULL
);

-- Stem cell donors (autologous = the patient's own cells)
CREATE TABLE donors (
    donor_id         INTEGER PRIMARY KEY,
    donor_type       TEXT NOT NULL CHECK (donor_type IN
                         ('autologous', 'matched_related', 'matched_unrelated', 'haploidentical')),
    donor_sex        TEXT CHECK (donor_sex IN ('M', 'F')),
    donor_birth_date TEXT
);

-- One row per transplant procedure
CREATE TABLE transplants (
    transplant_id   INTEGER PRIMARY KEY,
    patient_id      INTEGER NOT NULL REFERENCES patients(patient_id),
    donor_id        INTEGER NOT NULL REFERENCES donors(donor_id),
    center_id       INTEGER NOT NULL REFERENCES centers(center_id),
    transplant_date TEXT    NOT NULL,
    cell_source     TEXT    NOT NULL CHECK (cell_source IN
                        ('bone_marrow', 'peripheral_blood', 'cord_blood')),
    conditioning    TEXT    CHECK (conditioning IN ('myeloablative', 'reduced_intensity'))
);

-- Follow-up visits after transplant
CREATE TABLE follow_ups (
    followup_id    INTEGER PRIMARY KEY,
    transplant_id  INTEGER NOT NULL REFERENCES transplants(transplant_id),
    followup_date  TEXT    NOT NULL,
    status         TEXT    NOT NULL CHECK (status IN ('alive', 'dead', 'lost_to_followup')),
    relapse        INTEGER CHECK (relapse IN (0, 1)),
    gvhd_grade     INTEGER CHECK (gvhd_grade BETWEEN 0 AND 4),  -- graft-versus-host disease
    cause_of_death TEXT
);

-- Data quality checks (filled by dq_report.py from queries/04_data_quality.sql)
CREATE TABLE dq_checks (
    check_id     TEXT PRIMARY KEY,               -- e.g. 'DQ01'
    severity     TEXT NOT NULL CHECK (severity IN ('high', 'medium', 'low')),
    target_table TEXT NOT NULL,                  -- table whose records the check flags
    description  TEXT NOT NULL
);

-- One row per record flagged by a check, tracked until it is resolved.
-- Life cycle of an issue:
--   open              flagged, not yet sent to the center
--   query_sent        the center has been asked to verify the record
--   resolved          the record was corrected (set automatically when a
--                     check no longer flags it)
--   confirmed_correct the center confirmed the value is right, so the
--                     issue is not raised again
CREATE TABLE dq_issues (
    issue_id       INTEGER PRIMARY KEY,
    check_id       TEXT    NOT NULL REFERENCES dq_checks(check_id),
    record_id      INTEGER NOT NULL,             -- ID in the check's target_table
    first_detected TEXT    NOT NULL,
    last_detected  TEXT    NOT NULL,
    status         TEXT    NOT NULL DEFAULT 'open' CHECK (status IN
                       ('open', 'query_sent', 'resolved', 'confirmed_correct')),
    status_date    TEXT,
    comment        TEXT,
    UNIQUE (check_id, record_id)                 -- the same issue is logged only once
);

-- Each issue with its check details and the center that reported the record.
-- The flagged record can live in different tables, so each table is joined
-- only when it is the check's target table.
CREATE VIEW dq_issue_details AS
SELECT i.issue_id, i.check_id, c.severity, c.description, c.target_table, i.record_id,
       i.status, i.first_detected, i.last_detected, i.status_date, i.comment,
       COALESCE(p.center_id, t.center_id, tf.center_id) AS center_id
FROM dq_issues AS i
JOIN dq_checks AS c ON c.check_id = i.check_id
LEFT JOIN patients    AS p  ON c.target_table = 'patients'    AND p.patient_id    = i.record_id
LEFT JOIN transplants AS t  ON c.target_table = 'transplants' AND t.transplant_id = i.record_id
LEFT JOIN follow_ups  AS f  ON c.target_table = 'follow_ups'  AND f.followup_id   = i.record_id
LEFT JOIN transplants AS tf ON tf.transplant_id = f.transplant_id;

-- Indexes make joins and lookups on foreign keys faster
CREATE INDEX idx_patients_center     ON patients(center_id);
CREATE INDEX idx_diagnoses_patient   ON diagnoses(patient_id);
CREATE INDEX idx_transplants_patient ON transplants(patient_id);
CREATE INDEX idx_transplants_donor   ON transplants(donor_id);
CREATE INDEX idx_followups_tx        ON follow_ups(transplant_id);
CREATE INDEX idx_dq_issues_status    ON dq_issues(status);

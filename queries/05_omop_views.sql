-- =============================================================
-- 05. Mapping to a simplified OMOP Common Data Model structure
-- =============================================================
-- The OMOP CDM is a standard format that lets different clinical
-- databases be analysed with the same code. Here, registry tables are
-- reshaped into a few OMOP-style tables using VIEWS (saved queries
-- that behave like tables).
--
-- Simplifications:
--  * Only a subset of columns of each OMOP table is created.
--  * Gender uses the standard OMOP concepts 8507 (male) and 8532 (female).
--  * Other *_concept_id columns are set to 0 ("not yet mapped"). In a real
--    mapping, ICD-10 codes would be mapped to standard SNOMED CT concepts
--    using the OHDSI Athena vocabularies.
-- =============================================================

DROP VIEW IF EXISTS omop_person;
DROP VIEW IF EXISTS omop_condition_occurrence;
DROP VIEW IF EXISTS omop_procedure_occurrence;
DROP VIEW IF EXISTS omop_death;

-- One row per person
CREATE VIEW omop_person AS
SELECT p.patient_id                                AS person_id,
       CASE p.sex WHEN 'M' THEN 8507
                  WHEN 'F' THEN 8532
                  ELSE 0 END                       AS gender_concept_id,
       CAST(strftime('%Y', p.birth_date) AS INT)   AS year_of_birth,
       CAST(strftime('%m', p.birth_date) AS INT)   AS month_of_birth,
       CAST(strftime('%d', p.birth_date) AS INT)   AS day_of_birth,
       p.center_id                                 AS care_site_id,
       p.patient_id                                AS person_source_value,
       p.sex                                       AS gender_source_value
FROM patients AS p;

-- Diagnoses become condition occurrences
CREATE VIEW omop_condition_occurrence AS
SELECT d.diagnosis_id   AS condition_occurrence_id,
       d.patient_id     AS person_id,
       0                AS condition_concept_id,        -- to be mapped via Athena
       d.diagnosis_date AS condition_start_date,
       d.icd10_code     AS condition_source_value
FROM diagnoses AS d;

-- Transplants become procedure occurrences
CREATE VIEW omop_procedure_occurrence AS
SELECT t.transplant_id   AS procedure_occurrence_id,
       t.patient_id      AS person_id,
       0                 AS procedure_concept_id,       -- to be mapped via Athena
       t.transplant_date AS procedure_date,
       dn.donor_type || ' / ' || t.cell_source AS procedure_source_value
FROM transplants AS t
JOIN donors AS dn ON dn.donor_id = t.donor_id;

-- Deaths: one row per person, earliest recorded death date
CREATE VIEW omop_death AS
SELECT t.patient_id          AS person_id,
       MIN(f.followup_date)  AS death_date,
       MAX(f.cause_of_death) AS cause_source_value
FROM follow_ups AS f
JOIN transplants AS t ON t.transplant_id = f.transplant_id
WHERE f.status = 'dead'
GROUP BY t.patient_id;

-- Quick check: how many rows landed in each OMOP view?
SELECT 'person' AS omop_table, COUNT(*) AS n_rows FROM omop_person
UNION ALL SELECT 'condition_occurrence', COUNT(*) FROM omop_condition_occurrence
UNION ALL SELECT 'procedure_occurrence', COUNT(*) FROM omop_procedure_occurrence
UNION ALL SELECT 'death', COUNT(*) FROM omop_death;

-- And a mapping completeness check: share of persons with a mapped gender
SELECT ROUND(100.0 * AVG(CASE WHEN gender_concept_id <> 0 THEN 1 ELSE 0 END), 1) AS pct_gender_mapped
FROM omop_person;

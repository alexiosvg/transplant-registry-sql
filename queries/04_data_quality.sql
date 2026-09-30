-- =============================================================
-- 04. Data quality checks
-- =============================================================
-- Each check returns the records that break a rule. An empty result
-- means the check passed. Column constraints in schema.sql already
-- block some errors (for example an invalid sex code), but many
-- problems only appear when comparing values across columns or tables.
--
-- Every check starts with a header line in the format
--   -- CHECK: <id> | <severity> | <table> | <description>
-- where <table> is the table whose records are flagged. The first
-- column of each query must be the ID of the flagged record in that
-- table. dq_report.py reads these headers to log issues and build
-- the data quality report.
-- =============================================================

-- CHECK: DQ01 | high | transplants | Transplant dated before the diagnosis
SELECT t.transplant_id, t.patient_id, d.diagnosis_date, t.transplant_date
FROM transplants AS t
JOIN diagnoses AS d ON d.patient_id = t.patient_id
WHERE t.transplant_date < d.diagnosis_date;

-- CHECK: DQ02 | high | follow_ups | Follow-up visit dated before its transplant
SELECT f.followup_id, f.transplant_id, t.transplant_date, f.followup_date
FROM follow_ups AS f
JOIN transplants AS t ON t.transplant_id = f.transplant_id
WHERE f.followup_date < t.transplant_date;

-- CHECK: DQ03 | high | patients | Birth date after registration date
SELECT patient_id, birth_date, registration_date
FROM patients
WHERE birth_date > registration_date;

-- CHECK: DQ04 | high | follow_ups | Visit recorded as alive after a recorded death
SELECT later.followup_id, later.transplant_id, death.followup_date AS death_date, later.followup_date
FROM follow_ups AS death
JOIN follow_ups AS later
  ON later.transplant_id = death.transplant_id
 AND later.followup_date > death.followup_date
WHERE death.status = 'dead'
  AND later.status = 'alive';

-- CHECK: DQ05 | medium | follow_ups | GvHD reported after an autologous transplant
SELECT f.followup_id, f.transplant_id, f.gvhd_grade
FROM follow_ups AS f
JOIN transplants AS t  ON t.transplant_id = f.transplant_id
JOIN donors      AS dn ON dn.donor_id     = t.donor_id
WHERE dn.donor_type = 'autologous'
  AND f.gvhd_grade > 0;

-- CHECK: DQ06 | medium | patients | Possible duplicate patients (same center, sex and birth date)
SELECT p1.patient_id, p2.patient_id AS possible_duplicate_of, p1.center_id, p1.birth_date
FROM patients AS p1
JOIN patients AS p2
  ON p1.center_id  = p2.center_id
 AND p1.sex        = p2.sex
 AND p1.birth_date = p2.birth_date
 AND p1.patient_id > p2.patient_id;

-- CHECK: DQ07 | medium | follow_ups | Death recorded without a cause
SELECT followup_id, transplant_id, followup_date
FROM follow_ups
WHERE status = 'dead'
  AND (cause_of_death IS NULL OR TRIM(cause_of_death) = '');

-- CHECK: DQ08 | medium | patients | Registered patient without any diagnosis
SELECT p.patient_id, p.registration_date
FROM patients AS p
LEFT JOIN diagnoses AS d ON d.patient_id = p.patient_id
WHERE d.diagnosis_id IS NULL;

-- CHECK: DQ09 | medium | transplants | Implausible age at transplant (below 0 or above 80)
SELECT t.transplant_id, p.patient_id,
       ROUND((julianday(t.transplant_date) - julianday(p.birth_date)) / 365.25, 1) AS age
FROM transplants AS t
JOIN patients AS p ON p.patient_id = t.patient_id
WHERE (julianday(t.transplant_date) - julianday(p.birth_date)) / 365.25 NOT BETWEEN 0 AND 80;

-- CHECK: DQ10 | low | patients | Missing sex
SELECT patient_id, center_id
FROM patients
WHERE sex IS NULL;

-- CHECK: DQ11 | low | transplants | Missing conditioning regimen
SELECT transplant_id, patient_id, transplant_date
FROM transplants
WHERE conditioning IS NULL;

-- CHECK: DQ12 | low | follow_ups | Missing GvHD grade after an allogeneic transplant
SELECT f.followup_id, f.transplant_id, f.followup_date
FROM follow_ups AS f
JOIN transplants AS t  ON t.transplant_id = f.transplant_id
JOIN donors      AS dn ON dn.donor_id     = t.donor_id
WHERE dn.donor_type <> 'autologous'
  AND f.gvhd_grade IS NULL;

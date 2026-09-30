-- =============================================================
-- 02. Joins: combining linked tables through their keys
-- =============================================================

-- Q2.1 INNER JOIN: each patient with their diagnosis
-- Only rows with a match in BOTH tables are kept.
SELECT p.patient_id, p.sex, d.icd10_code, d.disease_name, d.diagnosis_date
FROM patients AS p
JOIN diagnoses AS d ON d.patient_id = p.patient_id
ORDER BY p.patient_id
LIMIT 10;

-- Q2.2 Joining four tables: transplant, patient, donor and center
SELECT t.transplant_id,
       t.transplant_date,
       p.sex         AS patient_sex,
       dn.donor_type,
       t.cell_source,
       c.center_name,
       c.country
FROM transplants AS t
JOIN patients AS p  ON p.patient_id = t.patient_id
JOIN donors   AS dn ON dn.donor_id  = t.donor_id
JOIN centers  AS c  ON c.center_id  = t.center_id
ORDER BY t.transplant_date DESC
LIMIT 10;

-- Q2.3 LEFT JOIN: registered patients who never received a transplant
-- LEFT JOIN keeps every patient; transplant columns are NULL when there is no match.
SELECT p.patient_id, d.disease_name, p.registration_date
FROM patients AS p
LEFT JOIN transplants AS t ON t.patient_id = p.patient_id
LEFT JOIN diagnoses   AS d ON d.patient_id = p.patient_id
WHERE t.transplant_id IS NULL
ORDER BY p.registration_date;

-- Q2.4 Age at transplant, computed from two tables
-- julianday() turns a date into a number of days, so differences give durations.
SELECT t.transplant_id,
       p.patient_id,
       ROUND((julianday(t.transplant_date) - julianday(p.birth_date)) / 365.25, 1) AS age_at_transplant
FROM transplants AS t
JOIN patients AS p ON p.patient_id = t.patient_id
ORDER BY age_at_transplant DESC
LIMIT 10;

-- Q2.5 Latest follow-up per transplant, using a window function
-- ROW_NUMBER() numbers the visits of each transplant from newest (1) to oldest.
WITH ranked AS (
    SELECT f.*,
           ROW_NUMBER() OVER (PARTITION BY f.transplant_id
                              ORDER BY f.followup_date DESC) AS rn
    FROM follow_ups AS f
)
SELECT transplant_id, followup_date AS last_followup, status, relapse, gvhd_grade
FROM ranked
WHERE rn = 1
ORDER BY transplant_id
LIMIT 10;

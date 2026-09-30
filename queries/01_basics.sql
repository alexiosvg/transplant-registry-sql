-- =============================================================
-- 01. Basics: SELECT, WHERE, ORDER BY, LIMIT, DISTINCT, COUNT
-- =============================================================

-- Q1.1 Look at the first 5 patients
SELECT *
FROM patients
LIMIT 5;

-- Q1.2 How many patients are in the registry?
SELECT COUNT(*) AS n_patients
FROM patients;

-- Q1.3 Which countries have reporting centers? (DISTINCT removes repeats)
SELECT DISTINCT country
FROM centers
ORDER BY country;

-- Q1.4 Female patients registered in 2023 (filtering with WHERE)
SELECT patient_id, birth_date, registration_date
FROM patients
WHERE sex = 'F'
  AND registration_date BETWEEN '2023-01-01' AND '2023-12-31'
ORDER BY registration_date
LIMIT 10;

-- Q1.5 Transplants using cord blood, most recent first
SELECT transplant_id, patient_id, transplant_date
FROM transplants
WHERE cell_source = 'cord_blood'
ORDER BY transplant_date DESC;

-- Q1.6 Diagnoses whose ICD-10 code starts with C9 (leukaemias and myeloma)
SELECT icd10_code, disease_name, COUNT(*) AS n
FROM diagnoses
WHERE icd10_code LIKE 'C9%'
GROUP BY icd10_code, disease_name
ORDER BY n DESC;

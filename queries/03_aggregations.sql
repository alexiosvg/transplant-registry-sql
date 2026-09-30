-- =============================================================
-- 03. Aggregations: GROUP BY, HAVING, CASE, CTEs
-- =============================================================

-- Q3.1 Transplants per year and donor type
SELECT strftime('%Y', t.transplant_date) AS year,
       dn.donor_type,
       COUNT(*) AS n_transplants
FROM transplants AS t
JOIN donors AS dn ON dn.donor_id = t.donor_id
GROUP BY year, dn.donor_type
ORDER BY year, dn.donor_type;

-- Q3.2 Activity per center, keeping only centers with more than 55 transplants (HAVING)
SELECT c.center_name, c.country, COUNT(*) AS n_transplants
FROM transplants AS t
JOIN centers AS c ON c.center_id = t.center_id
GROUP BY c.center_id
HAVING COUNT(*) > 55
ORDER BY n_transplants DESC;

-- Q3.3 Autologous versus allogeneic transplants by disease (CASE creates categories)
SELECT d.disease_name,
       SUM(CASE WHEN dn.donor_type = 'autologous' THEN 1 ELSE 0 END)  AS autologous,
       SUM(CASE WHEN dn.donor_type <> 'autologous' THEN 1 ELSE 0 END) AS allogeneic
FROM transplants AS t
JOIN diagnoses AS d  ON d.patient_id = t.patient_id
JOIN donors    AS dn ON dn.donor_id  = t.donor_id
GROUP BY d.disease_name
ORDER BY autologous + allogeneic DESC;

-- Q3.4 Mean age at transplant by disease
SELECT d.disease_name,
       COUNT(*) AS n,
       ROUND(AVG((julianday(t.transplant_date) - julianday(p.birth_date)) / 365.25), 1) AS mean_age
FROM transplants AS t
JOIN patients  AS p ON p.patient_id = t.patient_id
JOIN diagnoses AS d ON d.patient_id = t.patient_id
GROUP BY d.disease_name
ORDER BY mean_age;

-- Q3.5 Crude outcome summary per donor type, using the last follow-up (CTE + window function)
-- Note: a crude proportion, not a proper survival analysis (no censoring).
WITH last_fu AS (
    SELECT f.transplant_id, f.status, f.relapse,
           ROW_NUMBER() OVER (PARTITION BY f.transplant_id ORDER BY f.followup_date DESC) AS rn
    FROM follow_ups AS f
)
SELECT dn.donor_type,
       COUNT(*) AS n_with_followup,
       ROUND(100.0 * AVG(CASE WHEN lf.status = 'dead' THEN 1 ELSE 0 END), 1) AS pct_dead_at_last_fu,
       ROUND(100.0 * AVG(lf.relapse), 1) AS pct_relapsed
FROM last_fu AS lf
JOIN transplants AS t  ON t.transplant_id = lf.transplant_id
JOIN donors      AS dn ON dn.donor_id     = t.donor_id
WHERE lf.rn = 1
GROUP BY dn.donor_type
ORDER BY dn.donor_type;

-- Q3.6 Distribution of worst GvHD grade after allogeneic transplants
WITH worst AS (
    SELECT f.transplant_id, MAX(f.gvhd_grade) AS worst_grade
    FROM follow_ups AS f
    JOIN transplants AS t  ON t.transplant_id = f.transplant_id
    JOIN donors      AS dn ON dn.donor_id     = t.donor_id
    WHERE dn.donor_type <> 'autologous'
    GROUP BY f.transplant_id
)
SELECT worst_grade, COUNT(*) AS n_transplants
FROM worst
GROUP BY worst_grade
ORDER BY worst_grade;

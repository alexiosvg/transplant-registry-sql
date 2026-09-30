-- =============================================================
-- 06. Query management: following up data quality issues
-- =============================================================
-- Run python dq_report.py first, so the dq_checks and dq_issues
-- tables are filled. dq_issue_details (a view defined in
-- schema.sql) adds the check details and the reporting center
-- to each issue.
-- =============================================================

-- Q6.1 How many issues are in each status?
SELECT status, COUNT(*) AS n_issues
FROM dq_issues
GROUP BY status
ORDER BY n_issues DESC;

-- Q6.2 Issues needing review per center, split by severity
-- These are the lists a query manager would send to each center.
SELECT c.center_name,
       SUM(CASE WHEN d.severity = 'high'   THEN 1 ELSE 0 END) AS high,
       SUM(CASE WHEN d.severity = 'medium' THEN 1 ELSE 0 END) AS medium,
       SUM(CASE WHEN d.severity = 'low'    THEN 1 ELSE 0 END) AS low,
       COUNT(*) AS total
FROM dq_issue_details AS d
JOIN centers AS c ON c.center_id = d.center_id
WHERE d.status IN ('open', 'query_sent')
GROUP BY c.center_id
ORDER BY total DESC;

-- Q6.3 Open issues for one center, ready to send as a query list
SELECT d.issue_id, d.check_id, d.description, d.target_table, d.record_id
FROM dq_issue_details AS d
JOIN centers AS c ON c.center_id = d.center_id
WHERE c.center_name = 'Hospital Clinic Barcelona'
  AND d.status = 'open'
ORDER BY CASE d.severity WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
         d.check_id;

-- Q6.4 Which checks generate the most unresolved issues?
SELECT d.check_id, d.description, COUNT(*) AS unresolved
FROM dq_issue_details AS d
WHERE d.status IN ('open', 'query_sent')
GROUP BY d.check_id
ORDER BY unresolved DESC;

-- Q6.5 How long have queries been waiting for an answer?
SELECT issue_id, check_id, record_id, status_date AS query_sent_on,
       CAST(julianday('now') - julianday(status_date) AS INT) AS days_waiting
FROM dq_issues
WHERE status = 'query_sent'
ORDER BY days_waiting DESC;

-- Examples of status updates. They are commented out so that running this file
-- does not change the data. Remove the "--" to try them, or use update_issue.py.
--
-- Mark all open issues of one center as sent:
-- UPDATE dq_issues
-- SET status = 'query_sent', status_date = DATE('now')
-- WHERE status = 'open'
--   AND issue_id IN (SELECT issue_id FROM dq_issue_details WHERE center_id = 1);
--
-- Record that a center confirmed a flagged value is correct:
-- UPDATE dq_issues
-- SET status = 'confirmed_correct', status_date = DATE('now'),
--     comment = 'Center confirmed: two different patients'
-- WHERE check_id = 'DQ06' AND record_id = 601;

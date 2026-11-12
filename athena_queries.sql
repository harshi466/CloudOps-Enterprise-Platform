-- Run in Athena (workgroup: <project>-<env>-wg, database: <project>_<env>_analytics)
-- 1. Spend by category (data warehouse query over streamed events)
SELECT category, COUNT(*) AS txns, ROUND(SUM(amount), 2) AS total
FROM expense_events GROUP BY category ORDER BY total DESC;

-- 2. Top spenders
SELECT user_id, ROUND(SUM(amount), 2) AS total FROM expense_events GROUP BY user_id ORDER BY total DESC LIMIT 10;

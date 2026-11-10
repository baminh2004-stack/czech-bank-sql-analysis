/* =====================================================================
   02_data_quality.sql
   Purpose : Check completeness and consistency before any analysis.
   ===================================================================== */

-- 1.1 Row counts per table
SELECT 'account' AS table_name, COUNT(*) AS row_count FROM clean_account
UNION ALL SELECT 'trans',    COUNT(*) FROM clean_trans
UNION ALL SELECT 'loan',     COUNT(*) FROM clean_loan
UNION ALL SELECT 'district', COUNT(*) FROM clean_district;

-- 1.2 Duplicate transaction IDs (expected: 0 rows)
SELECT trans_id, COUNT(*) AS times_found
FROM clean_trans
GROUP BY trans_id
HAVING COUNT(*) > 1;

-- 1.3 Orphan transactions: account_id not found in the account table (expected: 0)
SELECT COUNT(*) AS orphan_transactions
FROM clean_trans t
LEFT JOIN clean_account a ON a.account_id = t.account_id
WHERE a.account_id IS NULL;

-- 1.4 Transactions dated before their account was opened (expected: 0)
SELECT COUNT(*) AS trans_before_account_open
FROM clean_trans t
JOIN clean_account a ON a.account_id = t.account_id
WHERE t.trans_date < a.open_date;

-- 1.5 Missing or non-positive amounts
SELECT
    SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) AS missing_amount,
    SUM(CASE WHEN amount <= 0    THEN 1 ELSE 0 END) AS non_positive_amount
FROM clean_trans;

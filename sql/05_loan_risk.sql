/* =====================================================================
   05_loan_risk.sql
   Purpose : Credit risk view of the loan book.
             Default = status B (finished, not paid) or D (running, in debt).
   ===================================================================== */

-- 4.1 Loan book overview by status
SELECT
    status,
    status_label,
    COUNT(*)                 AS loans,
    ROUND(SUM(amount), 0)    AS total_amount,
    ROUND(AVG(amount), 0)    AS avg_amount,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct
FROM clean_loan
GROUP BY status, status_label
ORDER BY status;

-- 4.2 Default rate by loan size band and duration
SELECT
    CASE
        WHEN amount <  50000  THEN '1. < 50k'
        WHEN amount < 150000  THEN '2. 50k - 150k'
        WHEN amount < 300000  THEN '3. 150k - 300k'
        ELSE                       '4. >= 300k'
    END                                   AS amount_band,
    duration_months,
    COUNT(*)                              AS loans,
    SUM(is_default)                       AS defaults,
    ROUND(100.0 * SUM(is_default) / COUNT(*), 1) AS default_rate_pct
FROM clean_loan
GROUP BY amount_band, duration_months
ORDER BY amount_band, duration_months;

-- 4.3 Default rate by region
SELECT
    d.region,
    COUNT(*)                                       AS loans,
    SUM(l.is_default)                              AS defaults,
    ROUND(100.0 * SUM(l.is_default) / COUNT(*), 1) AS default_rate_pct,
    ROUND(AVG(d.avg_salary), 0)                    AS avg_salary_in_region
FROM clean_loan l
JOIN clean_account  a ON a.account_id  = l.account_id
JOIN clean_district d ON d.district_id = a.district_id
GROUP BY d.region
ORDER BY default_rate_pct DESC;

-- 4.4 Early-warning signal: account behaviour in the 90 days BEFORE the loan
--     Do future defaulters already look different before they borrow?
WITH pre_loan AS (
    SELECT
        l.loan_id,
        l.is_default,
        AVG(t.balance)                                          AS avg_balance_90d,
        MIN(t.balance)                                          AS min_balance_90d,
        SUM(CASE WHEN t.direction = 'Credit' THEN t.amount ELSE 0 END) AS inflow_90d,
        COUNT(t.trans_id)                                       AS trans_count_90d
    FROM clean_loan l
    LEFT JOIN clean_trans t
           ON t.account_id = l.account_id
          AND t.trans_date <  l.loan_date
          AND t.trans_date >= DATE_SUB(l.loan_date, INTERVAL 90 DAY)
    GROUP BY l.loan_id, l.is_default
)
SELECT
    CASE is_default WHEN 1 THEN 'Defaulted (B/D)' ELSE 'Performing (A/C)' END AS loan_group,
    COUNT(*)                        AS loans,
    ROUND(AVG(avg_balance_90d), 0)  AS avg_balance_before_loan,
    ROUND(AVG(min_balance_90d), 0)  AS avg_min_balance_before_loan,
    ROUND(AVG(inflow_90d), 0)       AS avg_inflow_before_loan,
    ROUND(AVG(trans_count_90d), 1)  AS avg_transactions_before_loan
FROM pre_loan
GROUP BY loan_group;

-- 4.5 Debt-service burden: monthly payment vs. average monthly inflow
WITH inflow AS (
    SELECT account_id,
           SUM(CASE WHEN direction = 'Credit' THEN amount ELSE 0 END)
             / COUNT(DISTINCT DATE_FORMAT(trans_date, '%Y-%m')) AS avg_monthly_inflow
    FROM clean_trans
    GROUP BY account_id
)
SELECT
    CASE
        WHEN l.monthly_payment / i.avg_monthly_inflow < 0.2 THEN '1. < 20%'
        WHEN l.monthly_payment / i.avg_monthly_inflow < 0.4 THEN '2. 20% - 40%'
        ELSE                                                     '3. >= 40%'
    END                                            AS payment_to_inflow,
    COUNT(*)                                       AS loans,
    ROUND(100.0 * SUM(l.is_default) / COUNT(*), 1) AS default_rate_pct
FROM clean_loan l
JOIN inflow i ON i.account_id = l.account_id
WHERE i.avg_monthly_inflow > 0
GROUP BY payment_to_inflow
ORDER BY payment_to_inflow;

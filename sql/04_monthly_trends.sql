/* =====================================================================
   04_monthly_trends.sql
   Purpose : Monthly cash-flow trend with month-over-month growth and
             cumulative totals (window functions: LAG, SUM OVER).
   ===================================================================== */

WITH monthly AS (
    SELECT
        DATE_FORMAT(trans_date, '%Y-%m')                                   AS month,
        SUM(CASE WHEN direction = 'Credit' THEN amount ELSE 0 END)      AS total_credit,
        SUM(CASE WHEN direction = 'Debit'  THEN amount ELSE 0 END)      AS total_debit,
        SUM(signed_amount)                                              AS net_flow,
        COUNT(*)                                                        AS transactions
    FROM clean_trans
    GROUP BY DATE_FORMAT(trans_date, '%Y-%m')
)
SELECT
    month,
    ROUND(total_credit, 0) AS total_credit,
    ROUND(total_debit, 0)  AS total_debit,
    ROUND(net_flow, 0)     AS net_flow,
    transactions,
    ROUND(100.0 * (total_credit - LAG(total_credit) OVER (ORDER BY month))
          / LAG(total_credit) OVER (ORDER BY month), 1)                AS credit_mom_growth_pct,
    ROUND(SUM(net_flow) OVER (ORDER BY month), 0)                      AS cumulative_net_flow
FROM monthly
ORDER BY month;

-- Mix of transaction types by year
WITH yearly AS (
    SELECT
        YEAR(trans_date) AS yr,
        operation,
        COUNT(*)         AS transactions,
        SUM(amount)      AS total_amount
    FROM clean_trans
    GROUP BY YEAR(trans_date), operation
)
SELECT
    yr                       AS year,
    operation,
    transactions,
    ROUND(total_amount, 0)   AS total_amount,
    ROUND(100.0 * transactions / SUM(transactions) OVER (PARTITION BY yr), 1) AS share_of_year_pct
FROM yearly
ORDER BY yr, transactions DESC;

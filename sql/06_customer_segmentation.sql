/* =====================================================================
   06_customer_segmentation.sql
   Purpose : Segment accounts by activity and balance (NTILE, RANK)
             and profile the owners.
   ===================================================================== */

WITH account_profile AS (
    SELECT
        t.account_id,
        COUNT(*)              AS trans_count,
        ROUND(AVG(t.balance), 0) AS avg_balance,
        MAX(t.trans_date)     AS last_activity
    FROM clean_trans t
    GROUP BY t.account_id
),
scored AS (
    SELECT
        *,
        NTILE(4) OVER (ORDER BY avg_balance) AS balance_quartile,   -- 4 = richest
        NTILE(4) OVER (ORDER BY trans_count) AS activity_quartile   -- 4 = most active
    FROM account_profile
)
SELECT
    CASE
        WHEN balance_quartile = 4 AND activity_quartile >= 3 THEN '1. High value & active'
        WHEN balance_quartile = 4                            THEN '2. High value, low activity'
        WHEN activity_quartile >= 3                          THEN '3. Active, lower balance'
        ELSE                                                      '4. Low value & low activity'
    END                         AS segment,
    COUNT(*)                    AS accounts,
    ROUND(AVG(avg_balance), 0)  AS avg_balance,
    ROUND(AVG(trans_count), 0)  AS avg_transactions
FROM scored
GROUP BY segment
ORDER BY segment;

-- Top 3 accounts by average balance in each region (RANK)
WITH ranked AS (
    SELECT
        d.region,
        a.account_id,
        ROUND(AVG(t.balance), 0) AS avg_balance,
        RANK() OVER (PARTITION BY d.region ORDER BY AVG(t.balance) DESC) AS rank_in_region
    FROM clean_trans t
    JOIN clean_account  a ON a.account_id  = t.account_id
    JOIN clean_district d ON d.district_id = a.district_id
    GROUP BY d.region, a.account_id
)
SELECT region, rank_in_region, account_id, avg_balance
FROM ranked
WHERE rank_in_region <= 3
ORDER BY region, rank_in_region;

-- Owner profile: gender and age group vs. loan default
SELECT
    o.gender,
    CASE
        WHEN o.age_in_1999 < 30 THEN '1. < 30'
        WHEN o.age_in_1999 < 45 THEN '2. 30 - 44'
        WHEN o.age_in_1999 < 60 THEN '3. 45 - 59'
        ELSE                         '4. 60+'
    END                                            AS age_group,
    COUNT(*)                                       AS loans,
    ROUND(100.0 * SUM(l.is_default) / COUNT(*), 1) AS default_rate_pct
FROM clean_loan l
JOIN clean_client_owner o ON o.account_id = l.account_id
GROUP BY o.gender, age_group
ORDER BY o.gender, age_group;

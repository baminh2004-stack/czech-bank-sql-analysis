/* =====================================================================
   03_balance_reconciliation.sql
   Purpose : Rebuild the running balance of every account from its transactions
             and compare it with the balance reported by the bank.
             expected_balance = previous balance + signed amount
   Note    : Several transactions can share the same date and trans_id does
             not always follow the real posting order, so the line-level checks
             (2.1, 2.2) over-count mismatches. Steps 2.3 - 2.5 run the
             order-independent day-to-day test. Run each query separately.
   ===================================================================== */

-- 2.1 Line-by-line check: sample of transactions whose balance does not reconcile
--     (heavy on 1M+ rows: run each query in this file separately)
WITH ordered AS (
    SELECT
        account_id,
        trans_id,
        trans_date,
        direction,
        operation,
        signed_amount,
        balance,
        LAG(balance) OVER (PARTITION BY account_id ORDER BY trans_date, trans_id) AS prev_balance
    FROM clean_trans
)
SELECT
    account_id,
    trans_id,
    trans_date,
    operation,
    prev_balance,
    signed_amount,
    ROUND(COALESCE(prev_balance, 0) + signed_amount, 2) AS expected_balance,
    balance                                              AS reported_balance,
    ROUND(balance - (COALESCE(prev_balance, 0) + signed_amount), 2) AS difference
FROM ordered
WHERE ABS(balance - (COALESCE(prev_balance, 0) + signed_amount)) > 0.01
ORDER BY account_id, trans_date, trans_id
LIMIT 100;   -- sample only: run 2.2 for the full count

-- 2.2 Reconciliation summary: how many transactions and accounts reconcile
WITH ordered AS (
    SELECT
        account_id,
        balance - (COALESCE(LAG(balance) OVER (PARTITION BY account_id ORDER BY trans_date, trans_id), 0)
                   + signed_amount) AS difference
    FROM clean_trans
)
SELECT
    COUNT(*)                                                         AS total_transactions,
    SUM(CASE WHEN ABS(difference) > 0.01 THEN 1 ELSE 0 END)          AS mismatched_transactions,
    ROUND(100.0 * SUM(CASE WHEN ABS(difference) > 0.01 THEN 1 ELSE 0 END) / COUNT(*), 3) AS mismatch_pct,
    COUNT(DISTINCT account_id)                                       AS total_accounts,
    COUNT(DISTINCT CASE WHEN ABS(difference) > 0.01 THEN account_id END) AS accounts_with_mismatch
FROM ordered;

-- 2.3 Daily totals per account (helper table, heavy step, run once)
DROP TABLE IF EXISTS recon_daily;
CREATE TABLE recon_daily AS
SELECT
    account_id,
    trans_date,
    COUNT(*)           AS transactions_in_day,
    SUM(signed_amount) AS day_net_amount
FROM clean_trans
GROUP BY account_id, trans_date;

-- 2.4 Day-to-day reconciliation (order-independent, no error propagation)
--     A day reconciles if  closing balance = previous day closing balance + day net amount.
--     Same-day ordering does not matter, and one break does not spill into later days.
--     Limitation: with several same-day transactions only the closing balance can be
--     verified, because the true posting order within the day is unknown.
DROP TABLE IF EXISTS recon_local;
CREATE TABLE recon_local AS
SELECT r.account_id, r.trans_date, r.transactions_in_day, r.day_net_amount, r.prev_date,
       MAX(CASE WHEN r.prev_date IS NULL THEN 1
                WHEN ABS(t.balance - p.balance - r.day_net_amount) < 0.01 THEN 1
                ELSE 0 END) AS reconciled
FROM (
    SELECT account_id, trans_date, transactions_in_day, day_net_amount,
           LAG(trans_date) OVER (PARTITION BY account_id ORDER BY trans_date) AS prev_date
    FROM recon_daily
) r
JOIN clean_trans t      ON t.account_id = r.account_id AND t.trans_date = r.trans_date
LEFT JOIN clean_trans p ON p.account_id = r.account_id AND p.trans_date = r.prev_date
GROUP BY r.account_id, r.trans_date, r.transactions_in_day, r.day_net_amount, r.prev_date;

-- 2.5 Reconciliation summary (fast)
SELECT
    COUNT(*)                                                     AS account_days,
    SUM(CASE WHEN reconciled = 0 THEN 1 ELSE 0 END)              AS day_breaks,
    ROUND(100.0 * SUM(CASE WHEN reconciled = 0 THEN 1 ELSE 0 END) / COUNT(*), 3) AS break_pct,
    COUNT(DISTINCT CASE WHEN reconciled = 0 THEN account_id END) AS accounts_with_breaks
FROM recon_local;

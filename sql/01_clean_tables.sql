/* =====================================================================
   01_clean_tables.sql
   Purpose : Build clean, typed tables from the raw Berka tables.
   Why     : Raw files store dates as YYMMDD numbers and use Czech labels.
             Raw columns are loaded as text, so all numbers are CAST
             explicitly. Results are stored as tables (not views) and
             indexed so queries on 1M+ transactions stay fast.
   Engine  : MySQL 8.0+
   ===================================================================== */

DROP TABLE IF EXISTS clean_account;
CREATE TABLE clean_account AS
SELECT
    CAST(account_id  AS SIGNED) AS account_id,
    CAST(district_id AS SIGNED) AS district_id,
    CASE frequency
        WHEN 'POPLATEK MESICNE'   THEN 'Monthly statement'
        WHEN 'POPLATEK TYDNE'     THEN 'Weekly statement'
        WHEN 'POPLATEK PO OBRATU' THEN 'Statement after transaction'
        ELSE frequency
    END AS statement_frequency,
    STR_TO_DATE(CONCAT('19', `date`), '%Y%m%d') AS open_date
FROM account;

DROP TABLE IF EXISTS clean_trans;
CREATE TABLE clean_trans AS
SELECT
    CAST(trans_id   AS SIGNED) AS trans_id,
    CAST(account_id AS SIGNED) AS account_id,
    STR_TO_DATE(CONCAT('19', `date`), '%Y%m%d') AS trans_date,
    CASE WHEN type = 'PRIJEM' THEN 'Credit' ELSE 'Debit' END AS direction,
    CASE operation
        WHEN 'VKLAD'          THEN 'Cash deposit'
        WHEN 'VYBER'          THEN 'Cash withdrawal'
        WHEN 'VYBER KARTOU'   THEN 'Card withdrawal'
        WHEN 'PREVOD Z UCTU'  THEN 'Incoming transfer'
        WHEN 'PREVOD NA UCET' THEN 'Outgoing transfer'
        ELSE 'Other / interest'
    END AS operation,
    CAST(amount  AS DECIMAL(15,2)) AS amount,
    CASE WHEN type = 'PRIJEM' THEN CAST(amount AS DECIMAL(15,2)) ELSE -CAST(amount AS DECIMAL(15,2)) END AS signed_amount,
    CAST(balance AS DECIMAL(15,2)) AS balance
FROM trans;

DROP TABLE IF EXISTS clean_loan;
CREATE TABLE clean_loan AS
SELECT
    CAST(loan_id    AS SIGNED) AS loan_id,
    CAST(account_id AS SIGNED) AS account_id,
    STR_TO_DATE(CONCAT('19', `date`), '%Y%m%d') AS loan_date,
    CAST(amount   AS DECIMAL(15,2))    AS amount,
    CAST(duration AS SIGNED) AS duration_months,
    CAST(payments AS DECIMAL(15,2))    AS monthly_payment,
    status,
    CASE status
        WHEN 'A' THEN 'Finished - paid'
        WHEN 'B' THEN 'Finished - not paid'
        WHEN 'C' THEN 'Running - OK'
        WHEN 'D' THEN 'Running - in debt'
    END AS status_label,
    CASE WHEN status IN ('B', 'D') THEN 1 ELSE 0 END AS is_default
FROM loan;

DROP TABLE IF EXISTS clean_district;
CREATE TABLE clean_district AS
SELECT
    CAST(A1  AS SIGNED) AS district_id,
    A2                   AS district_name,
    A3                   AS region,
    CAST(A4  AS SIGNED) AS inhabitants,
    CAST(A11 AS DECIMAL(15,2))    AS avg_salary
FROM district;

DROP TABLE IF EXISTS clean_client_owner;
CREATE TABLE clean_client_owner AS
/* One owner per account. birth_number = YYMMDD, women have MM + 50. */
SELECT
    CAST(d.account_id AS SIGNED) AS account_id,
    CAST(c.client_id  AS SIGNED) AS client_id,
    CASE WHEN CAST(SUBSTR(c.birth_number, 3, 2) AS SIGNED) > 50 THEN 'Female' ELSE 'Male' END AS gender,
    1999 - (1900 + CAST(SUBSTR(c.birth_number, 1, 2) AS SIGNED)) AS age_in_1999
FROM disp d
JOIN client c ON c.client_id = d.client_id
WHERE d.type = 'OWNER';

-- Indexes for fast joins and window functions
CREATE INDEX idx_clean_trans_acc_date ON clean_trans (account_id, trans_date, trans_id);
CREATE INDEX idx_clean_loan_acc       ON clean_loan (account_id);
CREATE INDEX idx_clean_account_id     ON clean_account (account_id);
CREATE INDEX idx_clean_district_id    ON clean_district (district_id);
CREATE INDEX idx_clean_owner_acc      ON clean_client_owner (account_id);

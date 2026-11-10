/* =====================================================================
   00_load_data.sql
   Purpose : Create the database and raw tables, then load the Berka files.
   Engine  : MySQL 8.0+ (run in MySQL Workbench)
   Before running:
     1. Run  SHOW VARIABLES LIKE 'secure_file_priv'  and copy the six
        .csv files into that folder (by default the MySQL Uploads folder).
     2. If your folder differs, replace the path below. Use forward
        slashes (/) even on Windows.
   Files are semicolon-separated with Windows line endings (CRLF).
   Raw columns are loaded as text and cast to proper types in
   01_clean_tables.sql.
   ===================================================================== */

CREATE DATABASE IF NOT EXISTS berka;
USE berka;

DROP TABLE IF EXISTS account, client, disp, loan, trans, district;

CREATE TABLE account (
    account_id  VARCHAR(255),
    district_id VARCHAR(255),
    frequency   VARCHAR(255),
    `date`      VARCHAR(255)
);

CREATE TABLE client (
    client_id    VARCHAR(255),
    birth_number VARCHAR(255),
    district_id  VARCHAR(255)
);

CREATE TABLE disp (
    disp_id    VARCHAR(255),
    client_id  VARCHAR(255),
    account_id VARCHAR(255),
    type       VARCHAR(255)
);

CREATE TABLE loan (
    loan_id    VARCHAR(255),
    account_id VARCHAR(255),
    `date`     VARCHAR(255),
    amount     VARCHAR(255),
    duration   VARCHAR(255),
    payments   VARCHAR(255),
    status     VARCHAR(255)
);

CREATE TABLE trans (
    trans_id   VARCHAR(255),
    account_id VARCHAR(255),
    `date`     VARCHAR(255),
    type       VARCHAR(255),
    operation  VARCHAR(255),
    amount     VARCHAR(255),
    balance    VARCHAR(255),
    k_symbol   VARCHAR(255),
    bank       VARCHAR(255),
    account    VARCHAR(255)
);

CREATE TABLE district (
    A1 VARCHAR(255), A2 VARCHAR(255), A3 VARCHAR(255), A4 VARCHAR(255),
    A5 VARCHAR(255), A6 VARCHAR(255), A7 VARCHAR(255), A8 VARCHAR(255),
    A9 VARCHAR(255), A10 VARCHAR(255), A11 VARCHAR(255), A12 VARCHAR(255),
    A13 VARCHAR(255), A14 VARCHAR(255), A15 VARCHAR(255), A16 VARCHAR(255)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/account.csv' INTO TABLE account
FIELDS TERMINATED BY ';' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES
(account_id, district_id, frequency, `date`);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/client.csv' INTO TABLE client
FIELDS TERMINATED BY ';' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES
(client_id, birth_number, district_id);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/disp.csv' INTO TABLE disp
FIELDS TERMINATED BY ';' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES
(disp_id, client_id, account_id, type);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/loan.csv' INTO TABLE loan
FIELDS TERMINATED BY ';' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES
(loan_id, account_id, `date`, amount, duration, payments, status);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/trans.csv' INTO TABLE trans
FIELDS TERMINATED BY ';' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES
(trans_id, account_id, `date`, type, operation, amount, balance, k_symbol, bank, account);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/district.csv' INTO TABLE district
FIELDS TERMINATED BY ';' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES
(A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, A13, A14, A15, A16);

-- Quick check: row counts should be about 4,500 / 5,369 / 5,369 / 682 / 1,056,320 / 77
SELECT 'account' AS t, COUNT(*) FROM account UNION ALL
SELECT 'client',  COUNT(*) FROM client  UNION ALL
SELECT 'disp',    COUNT(*) FROM disp    UNION ALL
SELECT 'loan',    COUNT(*) FROM loan    UNION ALL
SELECT 'trans',   COUNT(*) FROM trans   UNION ALL
SELECT 'district',COUNT(*) FROM district;

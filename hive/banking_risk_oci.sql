CREATE DATABASE IF NOT EXISTS banking;

CREATE EXTERNAL TABLE IF NOT EXISTS banking.transactions_csv_app_oci (
  txn_id STRING,
  txn_date STRING,
  account_id STRING,
  customer_id STRING,
  txn_type STRING,
  amount INT,
  currency STRING,
  channel STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  'separatorChar' = ',',
  'quoteChar'     = '"'
)
STORED AS TEXTFILE
LOCATION '${OCI_INPUT_URI}'
TBLPROPERTIES ("skip.header.line.count"="1");

DROP TABLE IF EXISTS banking.account_risk_oci;

CREATE TABLE banking.account_risk_oci AS
SELECT
  account_id,
  txn_date,
  COUNT(*) AS txn_count,
  SUM(CASE WHEN UPPER(txn_type)='CREDIT' THEN amount ELSE 0 END) AS credit_total,
  SUM(CASE WHEN UPPER(txn_type)='DEBIT'  THEN amount ELSE 0 END) AS debit_total,
  SUM(CASE WHEN UPPER(txn_type)='DEBIT'  THEN -amount ELSE amount END) AS net_amount,
  SUM(CASE WHEN amount >= 1000 THEN 1 ELSE 0 END) AS large_txn_count,
  CASE
    WHEN SUM(CASE WHEN amount >= 1000 THEN 1 ELSE 0 END) >= 1
         AND SUM(CASE WHEN UPPER(txn_type)='DEBIT' THEN -amount ELSE amount END) < 0
      THEN 'HIGH'
    WHEN SUM(CASE WHEN amount >= 1000 THEN 1 ELSE 0 END) >= 1
      THEN 'MEDIUM'
    ELSE 'LOW'
  END AS risk_level
FROM banking.transactions_csv_app_oci
WHERE LOWER(txn_id) <> 'txn_id'
GROUP BY account_id, txn_date;

CREATE DATABASE IF NOT EXISTS banking;

CREATE EXTERNAL TABLE IF NOT EXISTS banking.transactions_csv (
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
LOCATION 'hdfs://localhost:9000/apps/banking/input'
TBLPROPERTIES ("skip.header.line.count"="1");

CREATE TABLE IF NOT EXISTS banking.daily_balance_hdfs AS
SELECT
  account_id,
  txn_date,
  SUM(CASE WHEN UPPER(txn_type)='DEBIT' THEN -amount ELSE amount END) AS net_amount
FROM banking.transactions_csv
GROUP BY account_id, txn_date;

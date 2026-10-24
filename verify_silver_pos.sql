-- Run in a Databricks SQL notebook AFTER the silver pipeline has run.
-- Catalog / schema: mindit_training.bookstore_ec_silver

-- 1) Expected after batch 1 only:   2026-10-05 = 295
--    Expected after batch 1 + 2:    2026-10-05 = 365, 2026-10-07 = 85
SELECT business_date, SUM(line_amount) AS pos_net_sales
FROM mindit_training.bookstore_ec_silver.slv_pos_receipt_lines
WHERE receipt_status = 'COMPLETED'
GROUP BY business_date
ORDER BY business_date;

-- 2) Cancelled receipt REC003 is kept with its status but never counted above
SELECT receipt_id, status, receipt_total
FROM mindit_training.bookstore_ec_silver.slv_pos_receipts
ORDER BY receipt_ts;

-- 3) Late file: only REC006 should be flagged after batch 2
SELECT receipt_id, business_date, arrival_date, is_late_arrival
FROM mindit_training.bookstore_ec_silver.slv_pos_receipts
WHERE is_late_arrival;

-- 4) Split payment: REC002 = 50 CARD + 25 CASH = 75
SELECT payment_method, amount
FROM mindit_training.bookstore_ec_silver.slv_pos_payments
WHERE receipt_id = 'REC002';

-- 5) Quarantine should be empty for the fixture
SELECT * FROM mindit_training.bookstore_ec_silver.dq_pos_receipts_quarantine;

-- 6) How many records failed each check (from the pipeline event log)
SELECT
  e.name AS check_name,
  SUM(e.passed_records) AS passed,
  SUM(e.failed_records) AS failed
FROM (
  SELECT explode(from_json(
           details:flow_progress.data_quality.expectations,
           'array<struct<name:string,dataset:string,passed_records:bigint,failed_records:bigint>>')) AS e
  FROM event_log(TABLE(mindit_training.bookstore_ec_silver.slv_pos_receipts_parsed))
  WHERE event_type = 'flow_progress'
)
GROUP BY e.name
ORDER BY e.name;

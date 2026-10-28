-- =============================================================================
-- Silver: POS receipts, lines and payments
-- Lakeflow Spark Declarative Pipelines (SQL)
--
-- Pipeline settings:  default catalog = mindit_training
--                     default schema  = bookstore_ec_silver
-- Source:             mindit_training.bookstore_ec_bronze.pos_raw
--                     (one row per till file, receipts nested, all values as text)
--
-- Flow:  pos_raw -> slv_pos_receipts_parsed   (typed, checked, nothing dropped)
--                -> dq_pos_receipts_quarantine (receipts that fail a blocking check)
--                -> slv_pos_receipts_latest    (latest version of each receipt)
--                -> slv_pos_receipts / _lines / _payments  (valid receipts only)
-- =============================================================================


-- 1) Parse and check -----------------------------------------------------------
-- Every receipt version is kept here. Checks are declared as expectations so the
-- pipeline event log counts how many records failed each one.
--   FAIL UPDATE : stop the run (the file cannot even be placed without a header)
--   EXPECT      : count and keep; blocking ones are routed to quarantine below
CREATE OR REFRESH STREAMING TABLE slv_pos_receipts_parsed (
  CONSTRAINT file_header_present EXPECT (store_id IS NOT NULL AND till_id IS NOT NULL AND business_date IS NOT NULL) ON VIOLATION FAIL UPDATE,
  CONSTRAINT receipt_id_present EXPECT (receipt_id IS NOT NULL),
  CONSTRAINT receipt_ts_valid EXPECT (receipt_ts IS NOT NULL),
  CONSTRAINT receipt_total_valid EXPECT (receipt_total IS NOT NULL),
  CONSTRAINT status_known EXPECT (status IN ('COMPLETED', 'CANCELLED')),
  CONSTRAINT lines_match_total EXPECT (status <> 'COMPLETED' OR lines_amount = receipt_total),
  CONSTRAINT tenders_match_total EXPECT (status <> 'COMPLETED' OR paid_amount = receipt_total),
  CONSTRAINT receipt_date_matches_file EXPECT (CAST(receipt_ts AS DATE) = business_date)
)
COMMENT 'All POS receipt versions, typed, with check results. Nothing is dropped here.'
AS
WITH base AS (
  SELECT
    p.store_id,
    p.till_id,
    TRY_CAST(p.business_date AS DATE)                              AS business_date,
    r.receipt_id,
    r.cashier_id,
    TRY_CAST(r.receipt_timestamp AS TIMESTAMP)                     AS receipt_ts,
    r.status,
    NULLIF(r.corrected_from_receipt_id, '')                        AS corrected_from_receipt_id,
    TRY_CAST(r.receipt_total AS DECIMAL(12,2))                     AS receipt_total,
    aggregate(
      r.lines,
      CAST(0 AS DECIMAL(18,2)),
      (acc, ln) -> CAST(
        acc + TRY_CAST(ln.quantity AS DECIMAL(12,2)) * TRY_CAST(ln.unit_price AS DECIMAL(12,2))
            - TRY_CAST(ln.discount_amount AS DECIMAL(12,2))
        AS DECIMAL(18,2))
    )                                                              AS lines_amount,
    aggregate(
      filter(r.payments, pay -> pay.payment_status = 'SUCCEEDED'),
      CAST(0 AS DECIMAL(18,2)),
      (acc, pay) -> CAST(acc + TRY_CAST(pay.amount AS DECIMAL(12,2)) AS DECIMAL(18,2))
    )                                                              AS paid_amount,
    r.lines,
    r.payments,
    p._source_file                                                 AS source_file,
    p._ingested_at
  FROM STREAM(mindit_training.bookstore_ec_bronze.pos_raw) AS p
  LATERAL VIEW OUTER explode(p.receipts) t AS r
)
SELECT
  concat_ws('|', store_id, till_id, CAST(business_date AS STRING), receipt_id) AS receipt_key,
  store_id,
  till_id,
  business_date,
  receipt_id,
  cashier_id,
  receipt_ts,
  status,
  corrected_from_receipt_id,
  receipt_total,
  lines_amount,
  paid_amount,
  -- Arrival day taken from the batch folder name (bronze has no file timestamp yet).
  TRY_CAST(NULLIF(regexp_extract(source_file, 'arrived_([0-9]{4}-[0-9]{2}-[0-9]{2})', 1), '') AS DATE) AS arrival_date,
  TRY_CAST(NULLIF(regexp_extract(source_file, 'arrived_([0-9]{4}-[0-9]{2}-[0-9]{2})', 1), '') AS DATE) > business_date AS is_late_arrival,
  -- Blocking checks: a receipt with any of these never reaches the valid tables.
  filter(
    array(
      CASE WHEN receipt_id IS NULL                                            THEN 'missing_receipt_id' END,
      CASE WHEN receipt_ts IS NULL                                            THEN 'invalid_receipt_timestamp' END,
      CASE WHEN receipt_total IS NULL                                         THEN 'invalid_receipt_total' END,
      CASE WHEN status IS NULL OR status NOT IN ('COMPLETED', 'CANCELLED')    THEN 'unknown_status' END,
      CASE WHEN status = 'COMPLETED' AND lines_amount IS DISTINCT FROM receipt_total THEN 'lines_total_mismatch' END,
      CASE WHEN status = 'COMPLETED' AND paid_amount  IS DISTINCT FROM receipt_total THEN 'tender_total_mismatch' END
    ),
    x -> x IS NOT NULL
  ) AS blocking_failures,
  lines,
  payments,
  source_file,
  _ingested_at
FROM base;


-- 2) Quarantine ----------------------------------------------------------------
-- Rejected receipts stay visible with the reason. They never count as revenue.
CREATE OR REFRESH STREAMING TABLE dq_pos_receipts_quarantine
COMMENT 'POS receipts that failed a blocking check, with the failed checks.'
AS
SELECT
  receipt_key,
  store_id,
  till_id,
  business_date,
  receipt_id,
  status,
  receipt_total,
  lines_amount,
  paid_amount,
  array_join(blocking_failures, ', ') AS failed_checks,
  source_file,
  _ingested_at,
  current_timestamp()                 AS quarantined_at
FROM STREAM(slv_pos_receipts_parsed)
WHERE size(blocking_failures) > 0;


-- 3) Latest version of each receipt ---------------------------------------------
-- A till can send the same receipt again (for example with status CANCELLED).
-- The row with the newest ingestion time wins; the same receipt is never counted twice.
CREATE OR REFRESH STREAMING TABLE slv_pos_receipts_latest;

CREATE FLOW slv_pos_receipts_latest_flow AS AUTO CDC INTO slv_pos_receipts_latest
FROM STREAM(slv_pos_receipts_parsed)
KEYS (receipt_key)
SEQUENCE BY _ingested_at
STORED AS SCD TYPE 1;


-- 4) Valid silver tables ---------------------------------------------------------
CREATE OR REFRESH MATERIALIZED VIEW slv_pos_receipts
COMMENT 'One row per valid POS receipt (latest version). Cancelled receipts are kept with their status.'
AS
SELECT
  receipt_key,
  store_id,
  till_id,
  business_date,
  receipt_id,
  cashier_id,
  receipt_ts,
  status,
  corrected_from_receipt_id,
  receipt_total,
  arrival_date,
  is_late_arrival,
  source_file,
  _ingested_at
FROM slv_pos_receipts_latest
WHERE size(blocking_failures) = 0;


CREATE OR REFRESH MATERIALIZED VIEW slv_pos_receipt_lines
COMMENT 'One row per line of a valid POS receipt. line_amount = quantity x unit_price - discount_amount.'
AS
SELECT
  r.receipt_key,
  r.store_id,
  r.till_id,
  r.business_date,
  r.receipt_id,
  r.status                                              AS receipt_status,
  r.receipt_ts,
  concat_ws('|', r.receipt_key, ln.receipt_line_id)     AS receipt_line_key,
  ln.receipt_line_id,
  ln.product_code,
  TRY_CAST(ln.quantity AS INT)                          AS quantity,
  TRY_CAST(ln.unit_price AS DECIMAL(12,2))              AS unit_price,
  TRY_CAST(ln.discount_amount AS DECIMAL(12,2))         AS discount_amount,
  NULLIF(ln.promotion_code, '')                         AS promotion_code,
  TRY_CAST(ln.quantity AS DECIMAL(12,2)) * TRY_CAST(ln.unit_price AS DECIMAL(12,2))
    - TRY_CAST(ln.discount_amount AS DECIMAL(12,2))     AS line_amount
FROM slv_pos_receipts_latest AS r
LATERAL VIEW explode(r.lines) t AS ln
WHERE size(r.blocking_failures) = 0;


CREATE OR REFRESH MATERIALIZED VIEW slv_pos_payments
COMMENT 'One row per payment tender of a valid POS receipt (split payments give several rows).'
AS
SELECT
  r.receipt_key,
  r.store_id,
  r.till_id,
  r.business_date,
  r.receipt_id,
  r.status                                              AS receipt_status,
  pay.pos_payment_id,
  pay.payment_method,
  TRY_CAST(pay.amount AS DECIMAL(12,2))                 AS amount,
  pay.payment_status,
  pay.currency
FROM slv_pos_receipts_latest AS r
LATERAL VIEW explode(r.payments) t AS pay
WHERE size(r.blocking_failures) = 0;

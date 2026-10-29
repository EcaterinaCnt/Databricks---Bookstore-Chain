
-- ============================================================
-- Bookstore - Scenario 1
-- Silver POS V2: Parse and validate receipts
--
-- Source:
-- mindit_training.bookstore_ec_bronze.pos_lf_raw
--
-- Target:
-- mindit_training.bookstore_ec_silver.slv_pos_receipts_parsed_v2
--
-- Purpose:
-- Safely migrate POS parsing to Lakeflow Bronze.
-- Original Silver tables remain unchanged.
-- ============================================================

CREATE OR REFRESH STREAMING TABLE slv_pos_receipts_parsed_v2 ( 
    
# Defining constraints for the Silver POS receipts table

  CONSTRAINT file_header_present
    EXPECT (
      store_id IS NOT NULL
      AND till_id IS NOT NULL
      AND business_date IS NOT NULL
    ) ON VIOLATION FAIL UPDATE,

  CONSTRAINT receipt_id_present
    EXPECT (receipt_id IS NOT NULL),

  CONSTRAINT receipt_ts_valid
    EXPECT (receipt_ts IS NOT NULL),

  CONSTRAINT receipt_total_valid
    EXPECT (receipt_total IS NOT NULL),

  CONSTRAINT status_known
    EXPECT (status IN ('COMPLETED', 'CANCELLED')),

  CONSTRAINT lines_match_total
    EXPECT (
      status <> 'COMPLETED'
      OR lines_amount = receipt_total
    ),

  CONSTRAINT tenders_match_total
    EXPECT (
      status <> 'COMPLETED'
      OR paid_amount = receipt_total
    ),

  CONSTRAINT receipt_date_matches_file
    EXPECT (CAST(receipt_ts AS DATE) = business_date)

)

COMMENT 'V2 POS receipt parsing from Lakeflow-managed Bronze.'

AS

WITH base AS (

  SELECT
    p.store_id,
    p.till_id,

    TRY_CAST(p.business_date AS DATE) AS business_date,

    r.receipt_id,
    r.cashier_id,

    TRY_CAST(
      r.receipt_timestamp AS TIMESTAMP
    ) AS receipt_ts,

    r.status,

    NULLIF(
      r.corrected_from_receipt_id, ''
    ) AS corrected_from_receipt_id,

    TRY_CAST(
      r.receipt_total AS DECIMAL(12,2)
    ) AS receipt_total,

    -- Calculate products after discounts
    aggregate(
      r.lines,
      CAST(0 AS DECIMAL(18,2)),
      (acc, ln) -> CAST(
        acc
        + TRY_CAST(ln.quantity AS DECIMAL(12,2))
          * TRY_CAST(ln.unit_price AS DECIMAL(12,2))
        - TRY_CAST(ln.discount_amount AS DECIMAL(12,2))
        AS DECIMAL(18,2)
      )
    ) AS lines_amount,
-- ============================================================
-- Sum only successful POS payments
-- ============================================================
    aggregate(
      filter(
        r.payments,
        pay -> pay.payment_status = 'SUCCEEDED'
      ),
      CAST(0 AS DECIMAL(18,2)),
      (acc, pay) -> CAST(
        acc + TRY_CAST(pay.amount AS DECIMAL(12,2))
        AS DECIMAL(18,2)
      )
    ) AS paid_amount,

    r.lines,
    r.payments,

    p._source_file AS source_file,
    p._ingested_at

  FROM STREAM(
    mindit_training.bookstore_ec_bronze.pos_lf_raw
  ) AS p

  LATERAL VIEW OUTER explode(p.receipts) t AS r
) 



-- ============================================================
-- Selecting and transforming POS receipt data for the Silver layer
-- ============================================================

SELECT 

  concat_ws(
    '|',
    store_id,
    till_id,
    CAST(business_date AS STRING),
    receipt_id
  ) AS receipt_key,

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

-- ============================================================
-- Identify the file arrival date
-- ============================================================
  
  TRY_CAST(
    NULLIF(
      regexp_extract(
        source_file,
        'arrived_([0-9]{4}-[0-9]{2}-[0-9]{2})',
        1
      ),
      ''
    ) AS DATE
  ) AS arrival_date,


  -- Identify late-arriving data
  TRY_CAST(
    NULLIF(
      regexp_extract(
        source_file,
        'arrived_([0-9]{4}-[0-9]{2}-[0-9]{2})',
        1
      ),
      ''
    ) AS DATE
  ) > business_date AS is_late_arrival,

-- ============================================================
-- Identify invalid receipts
-- ============================================================
  filter(
    array(

      CASE
        WHEN receipt_id IS NULL
        THEN 'missing_receipt_id'
      END,

      CASE
        WHEN receipt_ts IS NULL
        THEN 'invalid_receipt_timestamp'
      END,

      CASE
        WHEN receipt_total IS NULL
        THEN 'invalid_receipt_total'
      END,

      CASE
        WHEN status IS NULL
          OR status NOT IN ('COMPLETED', 'CANCELLED')
        THEN 'unknown_status'
      END,

      CASE
        WHEN status = 'COMPLETED'
          AND lines_amount IS DISTINCT FROM receipt_total
        THEN 'lines_total_mismatch'
      END,

      CASE
        WHEN status = 'COMPLETED'
          AND paid_amount IS DISTINCT FROM receipt_total
        THEN 'tender_total_mismatch'
      END

    ),
    x -> x IS NOT NULL
  ) AS blocking_failures,

  lines,
  payments,
  source_file,
  _ingested_at

FROM base; 

-- ============================================================
-- 2. Quarantine invalid POS receipts - V2
-- ============================================================

CREATE OR REFRESH STREAMING TABLE dq_pos_receipts_quarantine_v2

COMMENT 'Invalid POS receipts from the V2 Silver pipeline.'

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

    array_join(
        blocking_failures, ', '
    ) AS failed_checks,

    source_file,
    _ingested_at,

    current_timestamp() AS quarantined_at

FROM STREAM(slv_pos_receipts_parsed_v2)

WHERE size(blocking_failures) > 0;


-- ============================================================
-- 3. Valid receipt events - V2
-- Only valid receipt versions can update the latest state.
-- ============================================================

CREATE OR REFRESH STREAMING TABLE slv_pos_receipts_valid_events_v2
COMMENT 'Validated POS receipt events eligible for AUTO CDC.'
AS
SELECT *
FROM STREAM(slv_pos_receipts_parsed_v2)
WHERE size(blocking_failures) = 0
  AND receipt_key IS NOT NULL
  AND receipt_id IS NOT NULL
  AND arrival_date IS NOT NULL
  AND _ingested_at IS NOT NULL;


-- ============================================================
-- 4. Latest receipt version - V2
-- SCD Type 1: one current record per receipt.
-- ============================================================

CREATE OR REFRESH STREAMING TABLE slv_pos_receipts_latest_v2;

CREATE FLOW slv_pos_receipts_latest_v2_flow
AS AUTO CDC INTO slv_pos_receipts_latest_v2
FROM STREAM(slv_pos_receipts_valid_events_v2)

KEYS (receipt_key)

SEQUENCE BY STRUCT(
    arrival_date,
    _ingested_at,
    source_file
)

STORED AS SCD TYPE 1;


-- ============================================================
-- 5. SILVER V2 - POS Receipt Headers
-- Grain: one row per latest validated receipt
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW slv_pos_receipts_v2
COMMENT 'Latest validated POS receipt headers.'
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
FROM slv_pos_receipts_latest_v2;


-- ============================================================
-- 6. SILVER V2 - POS Receipt Lines
-- Grain: one product line per receipt
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW slv_pos_receipt_lines_v2
COMMENT 'Validated POS receipt lines and discounts.'
AS
SELECT
    r.receipt_key,
    r.store_id,
    r.till_id,
    r.business_date,
    r.receipt_id,
    r.status AS receipt_status,
    r.receipt_ts,

    concat_ws(
        '|',
        r.receipt_key,
        ln.receipt_line_id
    ) AS receipt_line_key,

    ln.receipt_line_id,
    ln.product_code,

    TRY_CAST(ln.quantity AS INT) AS quantity,

    TRY_CAST(
        ln.unit_price AS DECIMAL(12,2)
    ) AS unit_price,

    TRY_CAST(
        ln.discount_amount AS DECIMAL(12,2)
    ) AS discount_amount,

    NULLIF(
        ln.promotion_code, ''
    ) AS promotion_code,

    CAST(
        TRY_CAST(ln.quantity AS DECIMAL(12,2))
        * TRY_CAST(ln.unit_price AS DECIMAL(12,2))
        - TRY_CAST(ln.discount_amount AS DECIMAL(12,2))
        AS DECIMAL(18,2)
    ) AS line_amount

FROM slv_pos_receipts_latest_v2 AS r
LATERAL VIEW explode(r.lines) t AS ln;


-- ============================================================
-- 7. SILVER V2 - POS Payments
-- Grain: one payment tender per receipt
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW slv_pos_payments_v2
COMMENT 'Validated POS payment tenders, including split payments.'
AS
SELECT
    r.receipt_key,
    r.store_id,
    r.till_id,
    r.business_date,
    r.receipt_id,
    r.status AS receipt_status,

    pay.pos_payment_id,
    pay.payment_method,

    TRY_CAST(
        pay.amount AS DECIMAL(12,2)
    ) AS amount,

    pay.payment_status,
    pay.currency

FROM slv_pos_receipts_latest_v2 AS r
LATERAL VIEW explode(r.payments) t AS pay;

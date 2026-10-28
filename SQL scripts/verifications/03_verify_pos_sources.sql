-- READ ONLY: compare the old manually ingested Bronze and the new Lakeflow one.
-- Verify the ACTUAL schema of pos_lf_raw with 05_pipeline_resolution.sql first.
-- This version assumes pos_lf_raw publishes in bookstore_ec_bronze.
SELECT 'Manual Bronze' AS source, COUNT(*) AS file_count, SUM(SIZE(receipts)) AS receipt_count
FROM mindit_training.bookstore_ec_bronze.pos_raw
UNION ALL
SELECT 'Lakeflow Bronze' AS source, COUNT(*) AS file_count, SUM(SIZE(receipts)) AS receipt_count
FROM mindit_training.bookstore_ec_bronze.pos_lf_raw;

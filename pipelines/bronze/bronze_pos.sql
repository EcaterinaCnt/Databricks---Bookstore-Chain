-- RECONSTRUCTED CORRECTED LAKEFLOW POS BRONZE DEFINITION.
-- This is the declaration that succeeded after a standalone diagnostic SELECT
-- was removed from the pipeline transformation source.
-- WARNING: table name is unqualified. Its final schema is determined by the
-- pipeline's effective target catalog/schema. Verify information_schema before
-- assuming it is in mindit_training.bookstore_ec_bronze.
-- NOTE: standalone SELECT checks are stored in sql/verification/.
CREATE OR REFRESH STREAMING TABLE pos_lf_raw
COMMENT 'Incremental ingestion of daily POS JSON files'
AS
SELECT
    store_id,
    till_id,
    business_date,
    receipts,
    _metadata.file_path AS _source_file,
    current_timestamp() AS _ingested_at
FROM STREAM read_files(
    '/Volumes/mindit_training/bookstore_ec_bronze/bookstore_landing/landing/*/pos/*.json',
    format => 'json',
    multiLine => true
);

CREATE OR REFRESH STREAMING TABLE
mindit_training.bookstore_ec_bronze.pos_lf_raw

COMMENT 'Incremental POS ingestion from daily till JSON files'

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
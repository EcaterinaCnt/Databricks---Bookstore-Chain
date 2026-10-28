-- READ ONLY: locate the actual tables by catalog/schema; pipeline graph only
-- lists object names, so do not infer schema from the graph alone.
SELECT table_catalog, table_schema, table_name, table_type
FROM mindit_training.information_schema.tables
WHERE table_name IN (
  'pos_raw', 'pos_lf_raw', 'slv_pos_receipts_parsed', 'slv_pos_receipts_latest',
  'slv_pos_receipts', 'slv_pos_receipt_lines', 'slv_pos_payments'
)
ORDER BY table_schema, table_name;

-- Uploaded original slv_pos_receipts_parsed source SQL reads
-- STREAM(mindit_training.bookstore_ec_bronze.pos_raw).
-- Compare with the deployed Lakeflow source before claiming a dependency on pos_lf_raw.

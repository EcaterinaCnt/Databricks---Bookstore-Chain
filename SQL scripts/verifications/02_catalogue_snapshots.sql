-- READ ONLY: snapshot counts in the manually created catalogue raw table.
SELECT snapshot_date, COUNT(*) AS records
FROM mindit_training.bookstore_ec_bronze.product_catalogue_raw
GROUP BY snapshot_date ORDER BY snapshot_date;

SELECT _source_file, COUNT(*) AS records
FROM mindit_training.bookstore_ec_bronze.product_catalogue_raw
GROUP BY _source_file ORDER BY _source_file;

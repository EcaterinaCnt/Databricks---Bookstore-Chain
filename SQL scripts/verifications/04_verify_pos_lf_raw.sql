-- READ ONLY: resolve pos_lf_raw namespace before execution (query 05).
SELECT store_id, business_date, SIZE(receipts) AS receipt_count, _source_file
FROM mindit_training.bookstore_ec_bronze.pos_lf_raw
ORDER BY store_id;

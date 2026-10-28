-- READ ONLY. Run SQL Editor, not inside Lakeflow transformation source.
SELECT 'product_catalogue_raw' AS dataset, COUNT(*) AS records FROM mindit_training.bookstore_ec_bronze.product_catalogue_raw
UNION ALL SELECT 'stores_raw', COUNT(*) FROM mindit_training.bookstore_ec_bronze.stores_raw
UNION ALL SELECT 'store_closures_raw', COUNT(*) FROM mindit_training.bookstore_ec_bronze.store_closures_raw
UNION ALL SELECT 'pos_raw', COUNT(*) FROM mindit_training.bookstore_ec_bronze.pos_raw
UNION ALL SELECT 'online_orders_raw', COUNT(*) FROM mindit_training.bookstore_ec_bronze.online_orders_raw
UNION ALL SELECT 'online_order_lines_raw', COUNT(*) FROM mindit_training.bookstore_ec_bronze.online_order_lines_raw
UNION ALL SELECT 'online_order_status_raw', COUNT(*) FROM mindit_training.bookstore_ec_bronze.online_order_status_raw
UNION ALL SELECT 'online_payments_raw', COUNT(*) FROM mindit_training.bookstore_ec_bronze.online_payments_raw;

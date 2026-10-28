-- READ ONLY. Expected initial Oct 5 POS sales: 295 RON.
-- After a VERIFIED late-file Batch 2 processing: Oct 5 -> 365, Oct 7 -> 85.
SELECT business_date,
       SUM(line_amount) AS pos_net_sales,
       COUNT(*) AS completed_receipt_lines
FROM mindit_training.bookstore_ec_silver.slv_pos_receipt_lines
WHERE receipt_status = 'COMPLETED'
GROUP BY business_date
ORDER BY business_date;

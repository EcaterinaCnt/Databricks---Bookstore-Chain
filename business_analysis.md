**Understand the business.** Describe the business processes in the scenario: what happens, who is involved, and what data each step produces.

Process - Who/Where - Data Produced

In store sales - Customer/Cashier - POS eceipt header (store, till, cashier, timestamp, payment type, total)
                                  - POS receipt lines (product, qty, price, discount)

“3 for 2” promotion - Store, head office - discount on the cheapest of three eligible paperbacks, so the line price is 0 or a discount amount is recorded

Price change - Publisher, head office - actual selling price & catalogue price history (a sale must use the price valid at the sale time)

Receipt cancellation - Cashier - a cancelled receipt followed by a new correct one, so the cancelled receipt must not count as revenue

Return and refund - Customer, cashier - a refund receipt that references the original receipt, possibly from another store

Online order lifecycle - Customer, warehouse - order header and lines, with status changes (placed, paid, shipped, delivered, cancelled) arriving as repeated exports

Daily file delivery - Tills, IT - one file per till per day, sometimes arriving 2 days late

Master data - Head office - catalogue (new titles, delisted titles, formats), stores, cities, regions, regional managers, store open and close dates


**Q&A**

*Cancellation:* 

**-coloana status: cancel sau nu**
-is it like a flag for the original transaction, or a separate cancel event that references it?
-can the cancel arrive in a later file than the original? (the new correct receipt will have a new Receipt_ID therefore how will we know these are connected)
--poate sa vina mai tarziu
-the receipt is cancelled - it does not generate revenue - it can be followed by a new correct receipt - it is not necessarily a return

*Return:*

-the purchase must be valid - the revenue must be returned (-) - it refers an existing valid transaction - it can take place in another shop than the one where it has been bought the product 
--poate si in alt magazin

-which store gets the refund, if a book has been purchased in city A store Aa and returned in city B store Bb
--refund pe original shop

-returning promo 3 for 2 items, is the refund its full price/or the discounted amount based on the returned book
---- TO BE DISCUSSED 

-can only some items be returned
---- DA

-if the price after purchase drops, will the refund value the receipt or the new current price
---- ii dai cat a platit 

-is it allowed an online purchase return
---- ALLOWED

*Discount:*

-which paperbacks are eligible
-- TO BE DISCUSSED 

-what happens with 4/5/6 such books in the 3 for 2 rule
-- 

-does the free book count as unit_sold
-- este sold 

-how many products are in the basket 3 for 2 (1/2/3)
-- 3 dispar 

*Online Orders:*
--we take into cosideration that an online order can be paid only online and not to the courier--

-statuses: Placed --> Paid --> **one more status** --> Shipped --> Delivered 

-which date counts as revenue: Order Date/Payment Date/Shipping Date/Delivery Date
--dpdv contabil Payment Date

-can statuses be Out of order or Be repeated
--TOO COMPLICATED 

-can an order be cancelled after status Shipped and does it count as a Return
--ramane conditia ca nu mai poate fi cancelled after shipped, only returned 

-are there shipping fees, are these part of the net sales
-- TAKE into consid si shipping fee

-cancelled before vs after payment - is the payment refunded automatically, is an unpaid order a paid order for the cancellation rate
-- --ramane conditia ca nu mai poate fi cancelled after shipped, only returned 

-where there is no store in town, the region should come from the delivery address, is there a city to region mappping to cover every town
-- nu ne intereseaza intern, doar unde s a facut comanda 

-can we have the same customer_id with multiple email addresses, do we need such info about the customer or is it mask by customer_id
-- client unic


*Payment:*

-are there vouchers
--nu avem

-are there split plays card & cash
-- poate ambele 

-is the VAT included
-- este inclus

-at the time of sale it must be used a valid price, so the catalogue price should have validity dates --> what if the late file contains a sale form before a price change tahat a catalogue has already processed
-- odata actualizat catalogul, pretul se ia in considerare din catalog 

*Store:*

-can a cashier work in multiple stores
-- only one store 

-which are the business days -- working days

-region mapping
--fiecare store are o regiune

*File delivery:*

-a file arrives two days late, is the event date the sale date (so we restate past days), or the arrival date?
-the dashboard must show that earlier numbers were incomplete
--does not matter

-a store closed for renovation sends no file, and so does a store with a connection problem --> how do we tell them apart? We need an expected-files calendar from store open and close dates
--nu ne intereseaza 

-can the same file be sent twice, or replaced by a corrected version, is the file name or a content hash the unique key
--no

-is an empty file valid for a no sales day and what if a file is cut off mid-way
--nu se trimite 

-can the POS file format change over time
--no

*Master data:*

-is there a work/title ID linking hardcover and paperback,bc Without it we can’t roll formats up to titles
--does not matter

-do non-book items (stationery, games) have ISBNs or only internal codes
--doar ISBN 

-can a delisted title still be sold from remaining stock or be returned
--returned yes, sold no

-can a sale reference a product missing from the catalogue
--no

-can a product code be reused for a different product, or can the same book have several editions
--no

-if a regional manager changes, are past sales reported under the manager at that time or the current one
--no

-is there a specific history to be held in order to produce stores comparisons
--no

-should we take into cosideration promotions as well for specific products or start/end dates 
--yes (cateva doar)

-what is the baseline, the previous week, the same week last year, or a comparable store without the promotion


**KPIs**

*Net Sales:*
-sum of line amounts after discounts, minut refunds - we exclude cancelled receipts and cancelled online orders
-what about VAT
(day-store/channel-products)

*Units Sold:*
-units sold - units sold minus units returned, what about 3 for 2 
(day-store/channel-products)

*Average Basket:*
-average basket value - net sales / number of valid receipts or orders, refund receipts are excluded from the denominator, but what about 3 for 2
(day-store-channel)

*Items per Basket:*
-units / valid receipts or orders
(day-store-channel)

*Return rate:*
-refunded value / gross sales, a refund is attributed to the day of the refund, not the original sale
-or return value / sales value and returned units / sold units
(week-store)

*Sales per open day:*
-net sales / days the store was open, which keeps the renovated store and the new store comparable
-but to be discussed what is an open day
(month-store)

*Online share:*
-online net sales / total net sales
(month-region)

*Online cancellation rate:*
-cancelled orders / placed orders
(week)

*Order-to-ship time:*
-hours from payment to shipment, for shipped orders only
(week)

*Top and bottom titles:*
-net units ranked per title, with formats rolled up to the title level
(month-region)

*Data completeness:*
-stores with a file received vs expected for the day and till per day
(day-store)

**Assumptions**

-90 days of history, generated in daily batches
-POS data as daily JSON files per store
-online exports as CSV with upserts, and catalogue, stores and promotions as snapshots
-only online customers have personal data (name, email, phone, address) which are masked 

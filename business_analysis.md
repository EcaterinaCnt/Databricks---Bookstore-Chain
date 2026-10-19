**Understand the business.** Describe the business processes in the scenario: what happens, who is involved, and what data each step produces.

Process - Who/Where - Data Produced

In store sales - Customer/Cashier - POS receipt header (store, till, cashier, timestamp, payment type, total)
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
--no flag, it is a status

-can the cancel arrive in a later file than the original? (the new correct receipt will have a new Receipt_ID therefore how will we know these are connected)
--poate sa vina mai tarziu

-the receipt is cancelled - it does not generate revenue - it can be followed by a new correct receipt - it is not necessarily a return

*Return:*

-the purchase must be valid - the revenue must be returned (-) - it refers an existing valid transaction - it can take place in another shop than the one where it has been bought the product 
---- IT CAN BE IN ANOTHER SHOP ALSO

-which store gets the refund, if a book has been purchased in city A store Aa and returned in city B store Bb
---- REFUND IN THE ORIGINAL SHOP

-returning promo 3 for 2 items, is the refund its full price/or the discounted amount based on the returned book
--- WE DO NOT RETURN 3 FOR 2 PURCHASES

-can only some items be returned
---- YES

-if the price after purchase drops, will the refund value the receipt or the new current price
---- ii dai cat a platit 

-is it allowed an online purchase return
---- ALLOWED

*Discount:*

-which paperbacks are eligible

Defining eligibility through a promotion configuration rather than hardcoding a product list 
e.g. only products with category = 'Book' and format = 'Paperback' can qualify.

i.      The product must belong to the selected promotion.
ii.     The promotion must be active at the transaction timestamp.
iii.    Three eligible units form one promotional group.
iv.     For six eligible units, two groups qualify and two books are free.
v.      A product can have quantity greater than one, so eligibility is based on units rather than distinct ISBNs.
vi.     The promotion does not stack with other product discounts in the first version.


-what happens with 4/5/6 such books in the 3 for 2 rule
---- THE DISCOUNT GOES ON THE SAME LOGIC, NET -THE CHEAPEST, IF WE HAVE 6 THEN 1+1 ARE FREE

-does the free book count as unit_sold
---- YES, IT IS SOLD

-how many products are in the basket 3 for 2 (1/2/3)
---- 3 PRODS DISAPPEAR FROM STOCK, 3 PRODS ARE IN THE BASKET

*Online Orders:*
--we take into cosideration that an online order can be paid only online and not to the courier--
---- ACCEPTED

-statuses: Placed --> Paid --> **one more status** --> Shipped --> Delivered 
---- ANOTHER INTERMEDIATE STATUS: Ready for Delivery

-which date counts as revenue: Order Date/Payment Date/Shipping Date/Delivery Date
---- CONTABILITY RULES THAT THE PAYMENT DATE IS THE REVENUE DATE

-can statuses be Out of order or Be repeated
---- TOO COMPLICATED - WE CAN REMOVE THIS LOGIC

-can an order be cancelled after status Shipped and does it count as a Return
---- AFTER BEING SHIPPED, THE ORDER CANNOT BE CANCELLED, ONLY RETURNED

-are there shipping fees, are these part of the net sales
---- TAKE INTO CONSIDERATION THE SHIPPING FEE ALSO

-cancelled before vs after payment - is the payment refunded automatically, is an unpaid order a paid order for the cancellation rate
---- SAME AS ABOVE, AFTER BEING SHIPPED, THE ORDER CANNOT BE CANCELLED, ONLY RETURNED

-where there is no store in town, the region should come from the delivery address, is there a city to region mappping to cover every town
---- DOES NOT MATTER INTERN DETAILS, JUST THE STORE WHERE THE ORDER HAS BEEN MADE 

-can we have the same customer_id with multiple email addresses, do we need such info about the customer or is it mask by customer_id
---- THE CLIENT IS UNIQUE


*Payment:*

-are there vouchers
---- NO

-are there split plays card & cash
---- IT MAY POSSIBLE

-is the VAT included
---- IT IS ALREADY INCLUDED 

-at the time of sale it must be used a valid price, so the catalogue price should have validity dates --> what if the late file contains a sale form before a price change tahat a catalogue has already processed
---- ONCE UPDATED THE CATALOGUE, THE PRICE TAKEN INTO CONSID IS IN IT

*Store:*

-can a cashier work in multiple stores
---- ONLY ONE STORE 

-which are the business days 
---- WORKING DAYS 

-region mapping
---- EACH STORE HAS IT'S REGION 

*File delivery:*

-a file arrives two days late, is the event date the sale date (so we restate past days), or the arrival date?
-the dashboard must show that earlier numbers were incomplete

----- report by event date (receipt timestamp), keep the arrival timestamp in bronze, and accept that past days get restated
-- WHY do we need it?


-a store closed for renovation sends no file, and so does a store with a connection problem --> how do we tell them apart? We need an expected-files calendar from store open and close dates
---- DOES NOT MATTER 

-can the same file be sent twice, or replaced by a corrected version, is the file name or a content hash the unique key
---- NO

-is an empty file valid for a no sales day and what if a file is cut off mid-way
---- NO EMPTY FILES ARE SENT

-can the POS file format change over time
---- NO 

*Master data:*

-is there a work/title ID linking hardcover and paperback,bc Without it we can’t roll formats up to titles
---- DOES NOT MATTER 

-do non-book items (stationery, games) have ISBNs or only internal codes
---- JUST ISBN

-can a delisted title still be sold from remaining stock or be returned
---- RETURNED YES, SOLD NO

-can a sale reference a product missing from the catalogue
---- NO

-can a product code be reused for a different product, or can the same book have several editions
---- NO

-if a regional manager changes, are past sales reported under the manager at that time or the current one
---- NO

-is there a specific history to be held in order to produce stores comparisons
---- NO

-should we take into cosideration promotions as well for specific products or start/end dates 
---- YES, WILL SET JUST A FEW EASY ONES 

-what is the baseline, the previous week, the same week last year, or a comparable store without the promotion
---- THE COMMON ONES 

**KPIs**

-Diagrama cu procesul si evenimentele

*Net Sales:*
-sum of line amounts after discounts, minuS refunds - we exclude cancelled receipts and cancelled online orders
-what about VAT - VAT included 
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


**Refinment**

-- POS and receipts

Receipt numbers usually restart daily per till, so the key is (store, till, receipt number, RECEIPT date), not receipt number alone. --> MAYBE TIMESTAMP INSTEAD OF DATE
Carrier bags and gift wrap are IN CATALOG

non-catalogue items that distort items per basket --> WE DO NOT WRITE THESE DOWN ON RECEIPT?

Cancelling a refund receipt is possible, so refunds also need the COMPLETED check 
--TAKE INTO CONSID

--Returns

Return quantity cannot exceed purchased minus already returned -- RETURN DONE MEANS VERIFICATION DONE
A return must not point to a cancelled receipt
Returns can come in without a matching original, for example because the original file is late 
--TO BE DISCUSSED - SHOULD NOT TAKE INTO CONSID

?? Add a return window and a return reason such as "duplicate gift" -- CAN HAVE / CANNOT, depends on convinence 

--Online

An order can arrive in the export twice with the same status
--CAN

--Master data

A new store’s first file may arrive before it appears in the stores snapshot, and a new title can be sold before it is in the catalogue

TO REVIEW AND RESEARCH:

**DIMENSIONAL MODELLING - UNKNOWN MEMBER**

*Gross / Net Sales* calculation taking into consid the returns/cancellations

*Order to shipment time*

*Status assignment to order - online*

*Reporting date*



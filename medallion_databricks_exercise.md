# Medallion Architecture on Databricks: Bookstore Chain Case Study

## What You Need to Do

Below you'll find a description of a company and two scenarios from its daily business. There is no list of requirements. Everything you need is in the stories, the way you would hear it from a client.

Work through the following steps, first for Scenario 1 and then for Scenario 2:

1. **Understand the business.** Describe the business processes in the scenario: what happens, who is involved, and what data each step produces.
2. **Find the business questions.** Work out what the company needs to know to run and improve its business. Turn this into KPIs, each with a clear definition, a calculation rule (what is included and excluded) and a level of detail.
3. **Create the source data.** No data is provided. Decide which systems the company would have, what data they produce and in what form. Then write a generator that produces realistic data over time.
4. **Design the data model.** Design a data model for each layer of the medallion architecture (bronze, silver, gold) and explain the role of each layer and each table.
5. **Build the platform** on Databricks, following the technical requirements below.
6. **Build the report.** Create a dashboard in Databricks that management can use to answer their questions.
7. **Present your work.** Explain your assumptions, your decisions and your model. Show the dashboard, and trace at least one number from the dashboard back to the raw data.

Scenario 2 builds on Scenario 1. Extend the platform you already have rather than starting again.

If something isn't clear, ask your mentor, or make an assumption and write it down.

---

## The Company

The company is a bookstore chain with around 25 stores. The stores are in cities across the country, and the cities are grouped into regions. Larger cities have two or three stores, while smaller cities have one. Each region has a regional manager who is responsible for the stores in it.

The stores sell books, as well as stationery, board games and small gifts. Books come from many publishers. The same title is often available in more than one format, for example hardcover and paperback, and each format is a separate product with its own code and price.

The company also has an online shop. Online orders are shipped from a central warehouse to the customer's home address anywhere in the country.

Today, every store manager sends weekly totals in a spreadsheet to the head office. The online shop sends its own report, in a different format. At the monthly management meeting, nobody agrees on the numbers, and it takes days to answer simple questions. The head office decides each season which stores get more stock, which titles to reorder, which promotions to repeat, and where to open new stores. These decisions are made mostly on instinct.

The company wants to build a data platform on Databricks to change this.

---

## Scenario 1: A Day of Sales

A customer walks into one of the stores in the city centre. She picks up two novels and a notebook, goes to the till, and pays by card. The cashier scans each product. The receipt shows the store, the till, the cashier, the date and time, every product with its quantity and price, and the total.

This month, the store runs a **"3 for 2" promotion** on selected paperbacks. The next customer buys three of them, and the cheapest one is free. Another customer buys a hardcover that was **reduced in price last week**: the publisher lowered the recommended price, and the head office updated it in the product catalogue. A week ago, the same book cost more in every store.

Around noon, a cashier scans a product twice by mistake. She **cancels the receipt** and issues a new, correct one.

In the afternoon, a customer comes in to **return a book** with its receipt. He bought it last week, in another store in a different city, as a gift, and the person already had it. The store refunds him.

Meanwhile, orders arrive in the online shop. A customer orders three books for delivery to her home in a small town where the chain has no store. She pays online, and the order is shipped from the warehouse the next day. Another customer places an online order and **cancels it** an hour later, before it is shipped.

In the evening, each till sends the day's receipts to the head office as a file. One store has a problem with its internet connection, and its file **arrives two days later**. The online shop exports its orders several times a day. Each export contains the new orders and also the orders whose status changed since the last export, for example shipped, delivered or cancelled.

The product catalogue is maintained by the head office. New titles are added every week, prices change, and old titles are removed from sale. This month, a **new store opened** in one of the cities. Another store **was closed for two weeks** for renovation.

---

## Scenario 2: The Loyalty Programme

Six months after the sales platform goes live, the company launches a **loyalty programme**.

Customers can join for free, in a store or online, and receive a loyalty card. In stores, the customer shows the card at the till. Customers often forget it, though, and then the purchase is registered without a customer. Online, the customer logs in with their account, which uses the same customer number as the loyalty card.

For every purchase, the customer collects points. Points can be used as payment on later purchases, in a store or online.

Members have a **level** based on how much they spent in the last 12 months: **Standard**, **Silver** or **Gold**. Silver members get a 5% discount on every purchase, and Gold members get 10%. The level is recalculated every month, so a customer who spends a lot can move up, and one who spends less can move down.

A customer who joined in spring as Standard became Silver in the summer and Gold before Christmas. In January, after a quiet month, she dropped back to Silver. Another customer moved to a different city and updated his address. A third customer asked for her account to be **deleted**.

The loyalty system doesn't send all members every day. It sends only the **changes**: new members, updated profiles, level changes and deleted accounts. Because of the way the system works, these changes sometimes arrive **in the wrong order**.

During the same period, the head office **reorganises its regions**. From the first of next month, one city moves from one region to another and gets a new regional manager. Regional managers receive a yearly bonus based on the sales of their region. The head office also compares each region's sales with the previous year.

The marketing department wants to understand whether the loyalty programme is worth its cost. Management also wants to keep using the sales reports from Scenario 1, now with the new information included.

---

## Technical Requirements

- Build the platform on **Databricks**, using the **medallion architecture** (bronze, silver and gold).
- Use **Lakeflow Spark Declarative Pipelines** for loading and transforming the data.
- New data arrives over time. The platform must **process only new data** and must not load the same data twice.
- **Data quality:**
  - Your generated data must contain realistic problems, the kind that happen with real systems.
  - The pipelines must check the data and handle bad records deliberately. For each check, decide whether a bad record is kept, removed or stops the processing, and be able to explain why.
  - It must be possible to see how much data failed each check, and why, so that problems are noticed before anyone draws wrong conclusions from the report.
- **Personal data** (names, emails, phone numbers, addresses) must not be visible in the reporting layer.
- The pipelines must run on a **schedule**, without manual work.
- The code must be stored in **Git**.
- The report must be built with **Databricks dashboards** and read only from the gold layer.

How you meet these requirements is up to you. Explore what Databricks offers and choose the right tools.

---

## What You Will Practise

- **Business analysis:** understanding a business from a description, identifying processes, and asking the right questions.
- **KPI definition:** turning business needs into precise, unambiguous metrics.
- **Data modelling:** designing models for raw, clean and reporting data, choosing the level of detail, and modelling data that changes over time.
- **Medallion architecture:** the purpose of each layer and what belongs where.
- **Data engineering:** incremental ingestion, declarative pipelines, handling late and changing data.
- **Data quality:** finding, handling and monitoring bad data.
- **Data governance:** protecting personal data.
- **Orchestration:** automating and scheduling a data platform.
- **Reporting and visualisation:** building a dashboard people understand and trust.
- **Communication:** explaining decisions and assumptions to technical and non-technical people.

-- Step 0: Run in a Databricks SQL notebook cell, before creating anything.
SELECT current_catalog() AS catalog_name, current_schema() AS schema_name, current_user() AS user_name;
SHOW CATALOGS;
-- Review catalogs you can use. Do NOT attempt CREATE CATALOG in a company workspace.
-- Open Catalog Explorer, locate an accessible catalog/schema, and request/create a managed
-- volume named bookstore_landing if you have USE CATALOG, USE SCHEMA, CREATE VOLUME.
-- Example (replace placeholders before running):
-- CREATE VOLUME IF NOT EXISTS your_catalog.your_schema.bookstore_landing;
-- Data path: /Volumes/your_catalog/your_schema/bookstore_landing/landing/

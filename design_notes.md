# Design notes

## Architecture

The pipeline follows a standard staging -> intermediate -> marts layering in dbt, on top of a
DuckDB warehouse (`warehouse.duckdb`). See `README.md` for the full lineage diagram.

**Ingestion.** `ingest.py` reads the five raw files with DuckDB's `read_csv_auto` / `read_json_auto`
and writes them into a `raw` schema with `create or replace`. Re-running it always reflects the
current state of `data/raw/`. This is a full refresh, matching the source: a snapshot with no
change-tracking columns (no `updated_at`, no CDC).

**Staging** renames and types columns, and adds row-level validation flags
(`is_valid_currency_code`, `is_product_id_orphan`) without dropping a single row. `dq_exceptions`
unions the flagged rows from staging into one audit log, so every issue is visible and traceable
back to its source row instead of disappearing silently.

**Intermediate** solves the two hardest problems in the dataset:
- `int_fx_usd` converts every currency to USD for every order date, using DuckDB's native
  `asof join` against the two available FX snapshots, falling back to inversion when only the
  reverse rate is published, and to the earliest known rate for orders that predate the FX data.
- `int_order_items_enriched` joins each item to its order (for the date) and to its FX rate,
  keyed on the item's own currency, not the order header's, because the two can differ on the
  same order.

**Marts** are a small star schema. `fct_orders` (grain: one row per order) and `fct_order_items`
(grain: one row per line item) are the facts; `dim_products` and `dim_customers` are the
dimensions. `dim_products` carries an "Unknown" member so a line item referencing a product
outside the catalog still joins cleanly. Two reporting marts, `rpt_product_performance` and
`rpt_promo_timing`, sit on top of the facts and answer the two business questions directly.

## Currency normalization

Revenue is only ever reported in USD, computed at the line-item level from the item's own
currency and the order's date. When a currency can't be converted (an invalid code, or a date
outside FX coverage), the row keeps its place in every fact table with `revenue_usd` set to null
and a flag explaining why, rather than being dropped or defaulted to zero. Quantity sold doesn't
depend on currency at all, so it is never affected by this rule.

## Data quality findings

Source: `notebooks/01_eda.ipynb`. `[§N]` points to the matching numbered section.

- Volume: customers 50, orders 453, order_items 363, products 100. `id` unique on the first three. `[§1, §2]`
- Orders with no item: 93/453 (20.5%). `[§3]`
- Orphan product (`product_id` 101-110, outside the 1-100 catalog): 71/363 items (19.6%). `[§4]`
  → `dim_products` with an unknown member.
- 68 of 78 flagged items carry both invalid currency and orphan product. Clean coverage: 285/363 (78.5%). `[§5]`
- Invalid currency (`ABC`/`XYZ`/`QWE`): orders 79/453 (17.4%), order_items 75/363 (20.7%), starting 2024-08-03. `[§6, §7]`
  → row stays, `revenue_usd` null, goes into `dq_exceptions`.
- `orders.status`: single value, `completed`. `[§8]`
- **Header currency != item currency, same order**: 114/360 (31.7%). `order_items` does not inherit currency from `orders`. `[§9]`
  → FX join keys on `order_items.currency`. Custom test measures the divergence (baseline 114).
- `orders.total_amount` != sum of `order_items`: 193/360 (53.6%); 79 of those even when currency matches. `[§10, §11]`
  → `fct_orders` exposes `header_total_usd`, `items_rollup_total_usd`, `has_revenue_discrepancy`.
- `has_revenue_discrepancy` compares in USD, not native currency, so it differs from the 193 above: 116 true, 142 false, 195 null.
  Null breaks down as 93 orders with no item, 55 with an invalid header currency, 47 where every item's currency is invalid
  (`sum()` over an all-null group is null, not zero).
- fx_rates: 2 dates (2024-06-01, 2024-09-15) covering 236 days of orders; 55 orders (12%) predate the first. `[§12, §13]`
  → forward-fill to 2024-06-01, `fx_rate_source` column.
- GBP has no direct rate on 2024-09-15 → inverted via `base=USD`. Only such case; GBP is 4/453 orders. `[§14]`
- products.json: 100 ids (1-100), no gaps, no duplicates, currency always USD. `[§15]`
- Forward-fill sensitivity: top 10 by revenue shifts 2 positions when pre-June orders are included
  (ids 75, 78 in; ids 8, 15 out). `[§16]`

## Business marts

- `rpt_product_performance`: quantity counts every real-product line item regardless of currency (units sold
  don't need FX); revenue only sums where `revenue_usd` is convertible. Excludes `product_id = -1` (Unknown)
  from both rankings. Without that exclusion, Unknown's 174 units would outrank every real product (top
  real product is 40 units). Initial version filtered quantity by currency too, dropping 195/988 units
  (19.7%) for no reason tied to volume. Unknown's volume/revenue stays visible in the coverage panel of
  `02_business_answers.ipynb`.
- `rpt_promo_timing`: peak order count is 15:00 (72 orders); peak revenue is 14:00 (~$15.9k). The busiest
  hour is not the most profitable one. Orders only occur 9:00-18:00; no activity outside that window.

## What I'd change for production

- **Ingestion**: replace the full-refresh `create or replace` with an incremental extract keyed on
  a watermark or a CDC feed. A real orders table wouldn't fit a full re-read every run.
- **FX rates**: this dataset only has two snapshots. A real feed would have one rate per day (or
  more), and `int_fx_usd`'s `asof join` would need no fallback logic at all: the forward-fill and
  inversion branches exist because the sample data is sparse, not because they're good production
  patterns to keep around.
- **Orchestration**: this repo runs `ingest.py` then `dbt build` by hand. A production version
  would run both on a schedule (Airflow, Dagster, or similar), with dbt building only the new or
  changed rows (`is_incremental()`) instead of rebuilding every table from scratch each run.
- **Data quality**: `dq_exceptions` is a passive log today. Someone has to query it. In
  production it should alert when the volume of flagged rows moves outside a normal range, not
  just sit there.
- **Scale**: DuckDB fits this exercise's row counts. At "millions of orders" this would move to a
  warehouse built for concurrent writes and larger-than-memory joins (Snowflake, BigQuery, etc.),
  and the singular tests that pin exact row counts would need to become range or threshold checks
  instead, since exact counts stop being meaningful once the source keeps growing.

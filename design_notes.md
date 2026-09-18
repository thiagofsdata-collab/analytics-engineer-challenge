# Design notes

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
- fx_rates: 2 dates (2024-06-01, 2024-09-15) covering 236 days of orders; 55 orders (12%) predate the first. `[§12, §13]`
  → forward-fill to 2024-06-01, `fx_rate_source` column.
- GBP has no direct rate on 2024-09-15 → inverted via `base=USD`. Only such case; GBP is 4/453 orders. `[§14]`
- products.json: 100 ids (1-100), no gaps, no duplicates, currency always USD. `[§15]`
- Forward-fill sensitivity: top 10 by revenue shifts 2 positions when pre-June orders are included
  (ids 75, 78 in; ids 8, 15 out). `[§16]`

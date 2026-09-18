select count(distinct order_id) as mismatched_orders
from {{ ref('int_order_items_enriched') }}
where has_currency_mismatch
having count(distinct order_id) != 114

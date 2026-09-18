select count(*) as orphan_product_count
from {{ ref('stg_order_items') }}
where is_product_id_orphan
having count(*) != 71

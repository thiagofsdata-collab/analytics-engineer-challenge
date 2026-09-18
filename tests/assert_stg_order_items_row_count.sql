select count(*) as row_count
from {{ ref('stg_order_items') }}
having count(*) != 363

select source_table, record_id, dq_reason, count(*) as n
from {{ ref('dq_exceptions') }}
group by 1, 2, 3
having count(*) > 1

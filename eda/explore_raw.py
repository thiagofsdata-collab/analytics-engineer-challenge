import duckdb

con = duckdb.connect()

customers = "read_csv_auto('data/raw/customers.csv')"
orders = "read_csv_auto('data/raw/orders.csv')"
order_items = "read_csv_auto('data/raw/order_items.csv')"
products = "read_json_auto('data/raw/products.json')"
fx_rates = "read_json_auto('data/raw/fx_rates.json')"

print("row counts")
for label, rel in [
    ("customers", customers),
    ("orders", orders),
    ("order_items", order_items),
    ("products", products),
]:
    n = con.execute(f"select count(*) from {rel}").fetchone()[0]
    print(f"  {label}: {n}")

print()
print("key uniqueness (total rows vs distinct id)")
for label, rel in [("orders", orders), ("order_items", order_items), ("customers", customers)]:
    row = con.execute(f"select count(*), count(distinct id) from {rel}").fetchone()
    print(f"  {label}: {row}")

print()
print("orders with zero line items")
print(con.execute(f"""
    select count(*)
    from {orders} o
    left join {order_items} i on o.id = i.order_id
    where i.order_id is null
""").fetchone()[0])

print()
print("order_items.product_id not found in products.json")
print(con.execute(f"""
    select count(*) orphan_items, count(distinct i.product_id) distinct_orphan_ids
    from {order_items} i
    left join {products} p on i.product_id = p.id
    where p.id is null
""").fetchdf())

print()
print("orders.currency distribution")
print(con.execute(f"select currency, count(*) from {orders} group by 1 order by 2 desc").fetchdf())

print()
print("order_items.currency distribution")
print(con.execute(f"select currency, count(*) from {order_items} group by 1 order by 2 desc").fetchdf())

print()
print("orders.status distinct values")
print(con.execute(f"select distinct status from {orders}").fetchdf())

print()
print("order_date range vs fx_rates date coverage")
print("order_date min/max:", con.execute(f"select min(order_date), max(order_date) from {orders}").fetchone())
print("fx_rates dates:", con.execute(f"""
    select distinct r.date from (select unnest(responses) r from {fx_rates}) order by 1
""").fetchdf()["date"].tolist())

print()
print("orders header currency vs order_items currency, per order (all items in an order share one currency)")
print(con.execute(f"""
    with per_order as (
        select o.id, o.currency as header_currency, min(i.currency) as item_currency
        from {orders} o
        join {order_items} i on o.id = i.order_id
        group by 1, 2
    )
    select
        count(*) as orders_with_items,
        sum(case when header_currency != item_currency then 1 else 0 end) as currency_mismatch
    from per_order
""").fetchdf())

print()
print("orders.total_amount vs sum(order_items.quantity * unit_price), per order")
print(con.execute(f"""
    with items_rollup as (
        select order_id, sum(quantity * unit_price) as rollup_total
        from {order_items}
        group by 1
    )
    select
        count(*) as orders_with_items,
        sum(case when abs(o.total_amount - r.rollup_total) > 0.01 then 1 else 0 end) as amount_mismatch
    from {orders} o
    join items_rollup r on o.id = r.order_id
""").fetchdf())

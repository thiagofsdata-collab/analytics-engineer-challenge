import duckdb

warehouse = "warehouse.duckdb"

sources = [
    ("customers", "data/raw/customers.csv", "read_csv_auto"),
    ("orders", "data/raw/orders.csv", "read_csv_auto"),
    ("order_items", "data/raw/order_items.csv", "read_csv_auto"),
    ("products", "data/raw/products.json", "read_json_auto"),
    ("fx_rates", "data/raw/fx_rates.json", "read_json_auto"),
]


def main():
    con = duckdb.connect(warehouse)
    con.execute("create schema if not exists raw")
    for table, path, reader in sources:
        con.execute(f"""
            create or replace table raw.{table} as
            select *, current_timestamp as _loaded_at, '{path}' as _source_file
            from {reader}('{path}')
        """)
    con.close()


if __name__ == "__main__":
    main()

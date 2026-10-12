# Assumptions and UNVERIFIED items

This project was built without a live Looker instance and without a schema
file for `thelook_ecommerce` supplied by the project owner. Everything below
is either a dataset-column assumption or a LookML-feature assumption that
could not be checked against a live system. See
[../README.md](../README.md) for what *was* verified (structural LookML
correctness via `lkml` + `tools/check_lookml.py`).

## Dataset columns (table: `bigquery-public-data.thelook_ecommerce`)

Column names/types below are taken from the publicly documented structure
of the dataset, from memory, not from a live `INFORMATION_SCHEMA` query or
a schema file. They are believed correct but are marked UNVERIFIED because
they were not checked against the live table.

- **UNVERIFIED** — `users`: exact presence/spelling of `traffic_source`,
  `state`, `city`, `country`, `age`, `gender`, `created_at`. The dataset is
  also known to carry `street_address`, `postal_code`, `latitude`,
  `longitude` — deliberately **not used** in any view here, to avoid
  building on columns this project can't verify and doesn't need for the
  demo.
- **UNVERIFIED** — `products`: exact presence/spelling of `cost`,
  `category`, `brand`, `department`, `sku`, `distribution_center_id`.
- **UNVERIFIED** — `orders`: assumed primary key column is `order_id`
  (mapped to `dimension: id` in [orders.view.lkml](../views/orders.view.lkml)).
  Assumed columns: `user_id`, `status`, `created_at`, `shipped_at`,
  `delivered_at`, `returned_at`, `num_of_item`. The dataset is also known to
  carry a denormalized `gender` column on `orders` — deliberately **not
  used** here (it's redundant with `users.gender`).
- **UNVERIFIED** — `order_items`: assumed columns `id`, `order_id`,
  `user_id`, `product_id`, `inventory_item_id`, `status`, `created_at`,
  `sale_price`. The dataset is also known to carry `shipped_at`,
  `delivered_at`, `returned_at` on this table — not used here; `is_returned`
  is derived from `status` instead, to keep the shared-measure logic in one
  place.
- **UNVERIFIED** — `inventory_items`: this project only uses `id`,
  `product_id`, `created_at`, `sold_at`, `cost`. The dataset is known to
  also carry denormalized `product_*` columns (category, name, brand,
  retail price, department, sku, distribution center) — deliberately not
  used, since `products` already provides them via the join and duplicating
  both would risk divergent values.

If you have real access to this dataset (it's free to query against the
BigQuery public datasets program), the fix is mechanical: run
`bq show --schema bigquery-public-data:thelook_ecommerce.<table>` for each
table above and diff against the columns listed here.

## LookML features

- **Verified by this repo's own tooling** — `+view` refinement syntax,
  `derived_table` with `${view.SQL_TABLE_NAME}` substitution, and
  `dimension_group` timeframe expansion were all exercised by
  `tools/check_lookml.py` running against this project's own files (see
  README for how to run it). "Verified" here means *the `lkml` parser
  accepts the syntax and the checker's reference-resolution logic can find
  the fields it expects* — it does not mean a Looker server has rendered
  them.
- **UNVERIFIED (syntax believed correct per Looker's published LookML
  reference, not run live)** — `access_filter` block syntax and runtime
  behavior on the `order_items` explore
  ([ecommerce.model.lkml](../models/ecommerce.model.lkml)); Liquid parameter
  branching (`{% if revenue_metric._parameter_value == 'net' %}`) in
  [order_items_refinement.view.lkml](../views/order_items_refinement.view.lkml);
  `datagroup` + `persist_with` cache-trigger behavior; and every dashboard
  LookML field in
  [ecommerce_overview.dashboard.lookml](../dashboards/ecommerce_overview.dashboard.lookml)
  (listens, layout, element types) — the structural checker does not
  validate dashboard files at all (see README "What this does NOT prove").

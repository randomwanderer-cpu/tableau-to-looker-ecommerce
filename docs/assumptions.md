# Assumptions and UNVERIFIED items

This project was built without a live Looker instance and without a schema
file for `thelook_ecommerce` supplied by the project owner. Everything
below is either a dataset-column assumption or a LookML-feature assumption.
Each item is labeled with exactly what was and wasn't checked, and against
what — "verified" never means "run in a live Looker instance"; see
[../README.md](../README.md) for what that phrase is reserved for.

## Dataset columns (table: `bigquery-public-data.thelook_ecommerce`)

**Corroborated against two independent secondary sources, not primary-verified.**
The column lists below were originally written from memory. They have
since been cross-checked against two independent, non-Google write-ups
describing the live dataset (found via web search, October 2026), which
agree with each other and with the lists below — including less-obvious
details like `orders.num_of_item` (one other source suggested
`num_items_in_order`, but that appears to be a renamed column in a joined
*output*, not the base table name, per the corroborating sources). This is
real evidence, but it is still not the same as reading
`INFORMATION_SCHEMA.COLUMNS` off the live table or a schema file from the
project owner — no `bq`/`gcloud` CLI was available locally, and querying
BigQuery (even its no-cost Sandbox mode) requires a Google login this
project didn't use. If you have access, the authoritative fix is
mechanical: run `bq show --schema bigquery-public-data:thelook_ecommerce.<table>`
for each table below and diff against this list.

- `users`: `id`, `first_name`, `last_name`, `email`, `age`, `gender`,
  `state`, `city`, `country`, `traffic_source`, `created_at`. The dataset
  is also known to carry `street_address`, `postal_code`, `latitude`,
  `longitude` — deliberately **not used** in any view here, since this
  project doesn't need them.
- `products`: `id`, `cost`, `category`, `name`, `brand`, `retail_price`,
  `department`, `sku`, `distribution_center_id`.
- `orders`: primary key column `order_id` (mapped to `dimension: id` in
  [orders.view.lkml](../views/orders.view.lkml)). Columns used: `user_id`,
  `status`, `created_at`, `shipped_at`, `delivered_at`, `returned_at`,
  `num_of_item`. The dataset also carries a denormalized `gender` column on
  `orders` — deliberately **not used** here (redundant with `users.gender`).
- `order_items`: `id`, `order_id`, `user_id`, `product_id`,
  `inventory_item_id`, `status`, `created_at`, `sale_price`. The dataset
  also carries `shipped_at`, `delivered_at`, `returned_at` on this table —
  not used here; `is_returned` is derived from `status` instead, to keep
  the shared-measure logic in one place.
- `inventory_items`: this project only uses `id`, `product_id`,
  `created_at`, `sold_at`, `cost`. The dataset is known to also carry
  denormalized `product_*` columns (category, name, brand, retail price,
  department, sku, distribution center) — deliberately not used, since
  `products` already provides them via the join and duplicating both would
  risk divergent values.

## LookML features

### Verified against Looker's own published documentation (not run live)

These were checked against Looker's official reference pages (via web
search/fetch, October 2026), including exact quoted examples — a step up
from "believed correct from memory," but still never run in a live Looker
instance:

- **`dimension_group` field naming for `type: duration`** — Looker's own
  reference example (`param-field-dimension-group`) names a group
  `since_event` with `intervals: [hour, day]` and documents the generated
  fields as `hours_since_event` / `days_since_event`: the pluralized
  interval is *prefixed* onto the group name, not suffixed. This project's
  `order_items.since_created` (intervals: `[day]`) therefore generates
  `days_since_created`, per
  [order_items.view.lkml](../views/order_items.view.lkml).
  `tools/check_lookml.py` was fixed to expect this exact naming (it
  previously assumed the wrong, suffixed form) and
  `tests/test_checker.py::test_duration_dimension_group_field_names`
  encodes Looker's own example as a regression test.
- **`dynamic_fields` / `table_calculation` keys** — Looker's own reference
  (`param-lookml-dashboard-table-chart`) shows a worked `table_calculation`
  example (a `running_total`) using exactly the keys used in the new
  "Month-over-Month Revenue Change" element in
  [ecommerce_overview.dashboard.lookml](../dashboards/ecommerce_overview.dashboard.lookml):
  `table_calculation`, `label`, `expression`, `value_format_name`,
  `_kind_hint`, `_type_hint`, `is_disabled`.
- **`offset()` direction** — Looker's own best-practices guide
  ("how-to-calculate-percent-change-percent-previous") states that
  `offset(${field}, -1)` divides each value by "the value in the row that
  precedes it" — i.e. `-1` means the *previous* row, which is the direction
  this project's `mom_revenue_change` expression relies on (paired with an
  ascending `sorts: [order_items.created_month]` on that element).

### UNVERIFIED (my own construction; not confirmed anywhere)

- **The specific `mom_revenue_change` expression and element as a whole** —
  Looker's own documented `table_calculation` example is a `running_total`,
  not a ratio built from `offset()`. The *keys* and the *offset direction*
  above are each independently confirmed, but combining them into this
  exact ratio expression, on a `looker_grid` element, in this exact form,
  is this project's own construction and has never been run against a live
  Looker instance. If it's wrong, the likely failure mode is a parse/type
  error on the `expression` string, not a silently wrong number.
- **`access_filter` block syntax and runtime behavior** on the
  `order_items` explore
  ([ecommerce.model.lkml](../models/ecommerce.model.lkml)) — syntax
  believed correct per Looker's published LookML reference, not
  independently re-checked this pass.
- **Liquid parameter branching**
  (`{% if revenue_metric._parameter_value == 'net' %}`) in
  [order_items_refinement.view.lkml](../views/order_items_refinement.view.lkml)
  — same caveat.
- **`datagroup` + `persist_with` cache-trigger behavior** in
  [ecommerce.model.lkml](../models/ecommerce.model.lkml) — same caveat.
- **Every other dashboard LookML field** (listens, layout, single_value/
  looker_column/looker_bar element types) in
  [ecommerce_overview.dashboard.lookml](../dashboards/ecommerce_overview.dashboard.lookml)
  — the structural checker does not validate dashboard files at all (see
  README "What this does NOT prove").

### Verified by this repo's own tooling

`+view` refinement syntax, `derived_table` with `${view.SQL_TABLE_NAME}`
substitution, and `dimension_group` timeframe/duration expansion were all
exercised by `tools/check_lookml.py` and `tests/test_checker.py` running
against this project's own files. "Verified" here means *the `lkml` parser
accepts the syntax and the checker's reference-resolution logic can find
the fields it expects* — it does not mean a Looker server has rendered
them.

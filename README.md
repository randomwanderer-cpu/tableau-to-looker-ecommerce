# Tableau → Looker migration: ecommerce semantic layer

A small, honest portfolio project demonstrating a semantic layer built in
LookML, and a worked example of translating Tableau logic into it.

> **Syntax- and reference-checked offline; not run against a live Looker
> instance.** There is no Looker connection, no BigQuery connection, and no
> cost anywhere in this repo.

## What this is

- `models/ecommerce.model.lkml` + `views/*.view.lkml` — a LookML semantic
  layer over the public BigQuery dataset `bigquery-public-data.thelook_ecommerce`
  (referenced by table name only — no data is bundled or queried here).
- `docs/tableau_source_spec.md` — a written, **illustrative** Tableau
  dashboard spec (not a real workbook) used as the migration source.
- `docs/migration_playbook.md` — construct-by-construct mapping from that
  spec to this LookML project, what doesn't map cleanly, and why a
  Tableau → Looker migration is harder than the reverse.
- `tools/check_lookml.py` — a static checker (built on the `lkml` parser)
  that validates the LookML project's internal consistency.
- `tests/broken/` + `tests/test_checker.py` — a deliberately broken LookML
  fixture that proves the checker actually catches errors.

## What this proves

- I can design a Looker semantic layer: shared measures defined once
  (`order_items.view.lkml`: revenue, order count, return rate, average
  order value), a derived table standing in for a Tableau FIXED LOD
  (`customer_lifetime_value.view.lkml`), a `+view` refinement pattern
  (`order_items_refinement.view.lkml`), a parameter, and row-level security
  via an `access_filter`.
- I can read Tableau constructs (calculated fields, FIXED LODs, parameters,
  sets, table calculations, row-level security, extract schedules) and
  reason about their closest LookML equivalent — including where there
  isn't a clean one.
- I can build tooling (not just hand-write LookML) to catch structural
  mistakes before they'd ever reach a review.

## What this does NOT prove

- That any of this renders correctly in a live Looker instance.
  `access_filter` behavior, Liquid parameter branching, `datagroup` cache
  behavior, and every dashboard element are **believed correct per Looker's
  published LookML reference but untested live** — see
  [docs/assumptions.md](docs/assumptions.md) for the full list.
- That `thelook_ecommerce`'s actual column names match what's used here.
  They're taken from the dataset's publicly documented structure, not a
  live schema query — also flagged in `docs/assumptions.md`.
- That the Tableau spec reflects a real workbook. It doesn't; it's a
  written stand-in, labeled as such in the doc itself.
- SQL correctness against a real BigQuery warehouse (no connection was
  made — zero cost, per this project's own ground rules).

## Running the checker

```bash
python -m venv .venv
.venv\Scripts\activate   # (on Windows; use `source .venv/bin/activate` on macOS/Linux)
pip install lkml
python tools/check_lookml.py
```

Expected output: `check_lookml.py: OK — 6 view(s), 1 explore(s), no errors.`

To see the checker actually catch errors (it's tested against a
deliberately broken LookML fixture in `tests/broken/`):

```bash
python tests/test_checker.py
```

The same two commands run automatically on every push via
[.github/workflows/check.yml](.github/workflows/check.yml).

### What the checker checks

1. Every `${view.field}` / `${field}` reference resolves to a real,
   declared field (including fields added via a `+view` refinement, and
   the sub-fields a `dimension_group` expands into, e.g. `created_date`).
2. Every explore, and every join inside it, points to a real view.
3. No view declares the same field name twice.
4. Every view has at least one `primary_key: yes` dimension.

It does **not** validate dashboard LookML files, SQL dialect correctness,
or anything that requires a live Looker/warehouse connection — see
[docs/assumptions.md](docs/assumptions.md).

## Layout

```
models/ecommerce.model.lkml        connection, datagroup, explore, access_filter
views/users.view.lkml
views/products.view.lkml
views/inventory_items.view.lkml
views/orders.view.lkml
views/order_items.view.lkml        shared measures: revenue, order count, return rate, AOV
views/order_items_refinement.view.lkml   +view pattern: parameter + net-revenue measure
views/customer_lifetime_value.view.lkml  derived table replacing a Tableau FIXED LOD
dashboards/ecommerce_overview.dashboard.lookml
docs/tableau_source_spec.md         illustrative Tableau spec (not a real workbook)
docs/migration_playbook.md          construct-by-construct mapping + recommended approach
docs/assumptions.md                 every UNVERIFIED dataset/LookML assumption
tools/check_lookml.py               the structural checker
tests/broken/                       deliberately broken LookML, to prove the checker works
tests/test_checker.py
.github/workflows/check.yml
```

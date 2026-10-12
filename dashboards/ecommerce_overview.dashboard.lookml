- dashboard: ecommerce_overview
  title: Ecommerce Overview
  layout: newspaper
  description: |
    Mirrors the illustrative Tableau spec in docs/tableau_source_spec.md:
    revenue/order KPIs, a return-rate trend, and a state filter that is also
    enforced server-side via the access_filter in models/ecommerce.model.lkml.

  filters:
  - name: order_date
    title: Order Date
    type: field_filter
    default_value: 90 days
    allow_multiple_values: true
    required: false
    explore: order_items
    field: order_items.created_date

  - name: state
    title: Customer State
    type: field_filter
    default_value: ""
    allow_multiple_values: true
    required: false
    explore: order_items
    field: users.state

  elements:
  - name: Total Revenue
    title: Total Revenue
    type: single_value
    explore: order_items
    model: ecommerce
    fields: [order_items.total_revenue]
    listen:
      order_date: order_items.created_date
      state: users.state
    row: 0
    col: 0
    width: 6
    height: 4

  - name: Order Count
    title: Order Count
    type: single_value
    explore: order_items
    model: ecommerce
    fields: [order_items.order_count]
    listen:
      order_date: order_items.created_date
      state: users.state
    row: 0
    col: 6
    width: 6
    height: 4

  - name: Average Order Value
    title: Average Order Value
    type: single_value
    explore: order_items
    model: ecommerce
    fields: [order_items.average_order_value]
    listen:
      order_date: order_items.created_date
      state: users.state
    row: 0
    col: 12
    width: 6
    height: 4

  - name: Return Rate
    title: Return Rate
    type: single_value
    explore: order_items
    model: ecommerce
    fields: [order_items.return_rate]
    listen:
      order_date: order_items.created_date
      state: users.state
    row: 0
    col: 18
    width: 6
    height: 4

  - name: Revenue by Month
    title: Revenue by Month
    type: looker_column
    explore: order_items
    model: ecommerce
    fields: [order_items.created_month, order_items.total_revenue]
    listen:
      order_date: order_items.created_date
      state: users.state
    row: 4
    col: 0
    width: 12
    height: 8

  - name: Revenue by Product Category
    title: Revenue by Product Category
    type: looker_bar
    explore: order_items
    model: ecommerce
    fields: [products.category, order_items.total_revenue]
    sorts: [order_items.total_revenue desc]
    limit: 10
    listen:
      order_date: order_items.created_date
      state: users.state
    row: 4
    col: 12
    width: 12
    height: 8

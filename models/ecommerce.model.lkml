connection: "REPLACE_WITH_YOUR_CONNECTION_NAME"

include: "/views/*.view.lkml"

datagroup: ecommerce_default_datagroup {
  sql_trigger: SELECT MAX(created_at) FROM `bigquery-public-data.thelook_ecommerce.order_items` ;;
  max_cache_age: "24 hours"
}

persist_with: ecommerce_default_datagroup

explore: order_items {
  label: "Order Items"
  description: "Line-item grain. Start here for revenue, order, and return analysis."

  join: orders {
    type: left_outer
    sql_on: ${order_items.order_id} = ${orders.id} ;;
    relationship: many_to_one
  }

  join: users {
    type: left_outer
    sql_on: ${order_items.user_id} = ${users.id} ;;
    relationship: many_to_one
  }

  join: products {
    type: left_outer
    sql_on: ${order_items.product_id} = ${products.id} ;;
    relationship: many_to_one
  }

  join: inventory_items {
    type: left_outer
    sql_on: ${order_items.inventory_item_id} = ${inventory_items.id} ;;
    relationship: many_to_one
  }

  join: customer_lifetime_value {
    type: left_outer
    sql_on: ${order_items.user_id} = ${customer_lifetime_value.user_id} ;;
    relationship: many_to_one
  }

  # Row-level security: restricts rows to the viewer's own state, driven by a
  # Looker user attribute. Mirrors a Tableau row-level-security rule written
  # against a user filter on Customer State (see docs/tableau_source_spec.md).
  access_filter: {
    field: users.state
    user_attribute: state
  }
}

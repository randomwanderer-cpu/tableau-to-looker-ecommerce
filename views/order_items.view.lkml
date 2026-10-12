view: order_items {
  sql_table_name: `bigquery-public-data.thelook_ecommerce.order_items` ;;

  dimension: id {
    type: number
    primary_key: yes
    sql: ${TABLE}.id ;;
  }

  dimension: order_id {
    type: number
    hidden: yes
    sql: ${TABLE}.order_id ;;
  }

  dimension: user_id {
    type: number
    hidden: yes
    sql: ${TABLE}.user_id ;;
  }

  dimension: product_id {
    type: number
    hidden: yes
    sql: ${TABLE}.product_id ;;
  }

  dimension: inventory_item_id {
    type: number
    hidden: yes
    sql: ${TABLE}.inventory_item_id ;;
  }

  dimension: status {
    type: string
    sql: ${TABLE}.status ;;
  }

  dimension: is_returned {
    type: yesno
    sql: ${status} = 'Returned' ;;
  }

  dimension: sale_price {
    type: number
    value_format_name: usd
    sql: ${TABLE}.sale_price ;;
  }

  dimension_group: created {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.created_at ;;
  }

  # --- Shared measures: defined once here, reused across every explore and dashboard ---

  measure: item_count {
    type: count
    drill_fields: [id, order_id, status, sale_price]
  }

  measure: order_count {
    type: count_distinct
    sql: ${order_id} ;;
  }

  measure: total_revenue {
    type: sum
    sql: ${sale_price} ;;
    value_format_name: usd
  }

  measure: returned_item_count {
    type: count
    filters: [is_returned: "yes"]
  }

  measure: return_rate {
    type: number
    sql: SAFE_DIVIDE(${returned_item_count}, ${item_count}) ;;
    value_format_name: percent_1
  }

  measure: average_order_value {
    type: number
    sql: SAFE_DIVIDE(${total_revenue}, ${order_count}) ;;
    value_format_name: usd
  }
}

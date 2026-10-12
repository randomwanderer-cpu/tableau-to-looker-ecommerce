view: inventory_items {
  sql_table_name: `bigquery-public-data.thelook_ecommerce.inventory_items` ;;

  dimension: id {
    type: number
    primary_key: yes
    sql: ${TABLE}.id ;;
  }

  dimension: product_id {
    type: number
    hidden: yes
    sql: ${TABLE}.product_id ;;
  }

  dimension: cost {
    type: number
    value_format_name: usd
    sql: ${TABLE}.cost ;;
  }

  dimension_group: created {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.created_at ;;
  }

  dimension_group: sold {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.sold_at ;;
  }

  dimension: is_sold {
    type: yesno
    sql: ${sold_raw} IS NOT NULL ;;
  }

  measure: count {
    type: count
    drill_fields: [id, product_id]
  }

  measure: total_cost {
    type: sum
    sql: ${cost} ;;
    value_format_name: usd
  }
}

view: orders {
  sql_table_name: `bigquery-public-data.thelook_ecommerce.orders` ;;

  dimension: id {
    type: number
    primary_key: yes
    sql: ${TABLE}.order_id ;;
  }

  dimension: user_id {
    type: number
    hidden: yes
    sql: ${TABLE}.user_id ;;
  }

  dimension: status {
    type: string
    sql: ${TABLE}.status ;;
  }

  dimension: num_of_item {
    type: number
    sql: ${TABLE}.num_of_item ;;
  }

  dimension_group: created {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.created_at ;;
  }

  dimension_group: shipped {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.shipped_at ;;
  }

  dimension_group: delivered {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.delivered_at ;;
  }

  dimension_group: returned {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.returned_at ;;
  }

  dimension: is_returned {
    type: yesno
    sql: ${returned_raw} IS NOT NULL ;;
  }

  measure: count {
    type: count
    drill_fields: [id, status, created_date]
  }
}

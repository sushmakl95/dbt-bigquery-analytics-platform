-- Singular test: every order_item must reference an existing order.
-- Stronger than a generic `relationships` test because it filters to the
-- active (non-cancelled) orders only.

SELECT
    oi.order_id,
    oi.line_item_id,
    oi.order_item_sk
FROM {{ ref('stg_order_items') }} oi
LEFT JOIN {{ ref('stg_orders') }} o USING (order_id)
WHERE o.order_id IS NULL
   OR o.order_status = 'cancelled'
LIMIT 100

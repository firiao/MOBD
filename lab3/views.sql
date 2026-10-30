-- Лабораторная работа №3. Аналитические представления.
-- Создаются поверх схемы и данных лабораторных работ №1–2.
-- Скрипт можно выполнять повторно.

DROP VIEW IF EXISTS v_category_stats;
DROP VIEW IF EXISTS v_seller_revenue;
DROP VIEW IF EXISTS v_product_catalog;

-- Витрина каталога: товар, категория, продавец и остаток на складе.
CREATE VIEW v_product_catalog AS
SELECT p.id                         AS product_id,
       p.title,
       p.price,
       p.is_active,
       c.id                         AS category_id,
       c.name                       AS category_name,
       s.id                         AS seller_id,
       s.store_name                 AS seller_name,
       COALESCE(st.quantity, 0)     AS stock_quantity,
       p.created_at
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
JOIN sellers    AS s ON s.id = p.seller_id
LEFT JOIN stock AS st ON st.product_id = p.id;

-- Выручка продавцов по оплаченным и завершённым заказам.
CREATE VIEW v_seller_revenue AS
SELECT s.id                                                   AS seller_id,
       s.store_name,
       count(DISTINCT o.id)                                   AS orders_count,
       COALESCE(sum(oi.quantity), 0)                          AS units_sold,
       COALESCE(sum(oi.quantity * oi.unit_price), 0)          AS revenue,
       COALESCE(round(sum(oi.quantity * oi.unit_price)
                      / NULLIF(count(DISTINCT o.id), 0), 2), 0) AS avg_order_value
FROM sellers AS s
JOIN products AS p     ON p.seller_id = s.id
JOIN order_items AS oi ON oi.product_id = p.id
JOIN orders AS o       ON o.id = oi.order_id
WHERE o.status IN ('paid', 'shipped', 'delivered')
GROUP BY s.id, s.store_name;

-- Сводка по категориям: количество товаров, цены, активность, остаток.
CREATE VIEW v_category_stats AS
SELECT c.id                                                   AS category_id,
       c.name                                                 AS category_name,
       count(p.id)                                            AS products_count,
       count(p.id) FILTER (WHERE p.is_active)                 AS active_products,
       round(avg(p.price), 2)                                 AS avg_price,
       min(p.price)                                           AS min_price,
       max(p.price)                                           AS max_price,
       COALESCE(sum(st.quantity), 0)                          AS stock_total
FROM categories AS c
LEFT JOIN products AS p ON p.category_id = c.id
LEFT JOIN stock    AS st ON st.product_id = p.id
GROUP BY c.id, c.name;

-- Лабораторная работа №3. Многотабличные запросы и аналитические представления.
-- Перед запуском должны быть созданы схема (lab1), данные (lab2) и представления
-- (lab3/views.sql).
--
-- Запуск:
--   psql -d marketplace -f views.sql
--   psql -d marketplace -f queries.sql

\echo '=== Запрос 1. INNER JOIN трёх таблиц: товар — категория — продавец ==='
SELECT p.id, p.title, c.name AS category, s.store_name AS seller, p.price
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
JOIN sellers    AS s ON s.id = p.seller_id
WHERE p.is_active
ORDER BY p.price DESC
LIMIT 12;

\echo '=== Запрос 2. LEFT JOIN: товары без отзывов ==='
SELECT p.id, p.title, count(r.id) AS reviews_count
FROM products AS p
LEFT JOIN reviews AS r ON r.product_id = p.id
GROUP BY p.id, p.title
HAVING count(r.id) = 0
ORDER BY p.id
LIMIT 12;

\echo '=== Запрос 3. GROUP BY: количество товаров и средняя цена по категориям ==='
SELECT c.name AS category,
       count(p.id) AS products_count,
       round(avg(p.price), 2) AS avg_price,
       min(p.price) AS min_price,
       max(p.price) AS max_price
FROM categories AS c
JOIN products AS p ON p.category_id = c.id
WHERE p.is_active
GROUP BY c.id, c.name
ORDER BY avg_price DESC;

\echo '=== Запрос 4. HAVING: продавцы с выручкой выше 10 млн ==='
SELECT s.store_name,
       count(DISTINCT o.id) AS orders_count,
       sum(oi.quantity) AS units_sold,
       sum(oi.quantity * oi.unit_price) AS revenue
FROM sellers AS s
JOIN products AS p     ON p.seller_id = s.id
JOIN order_items AS oi ON oi.product_id = p.id
JOIN orders AS o       ON o.id = oi.order_id
WHERE o.status IN ('paid', 'shipped', 'delivered')
GROUP BY s.id, s.store_name
HAVING sum(oi.quantity * oi.unit_price) > 10000000
ORDER BY revenue DESC;

\echo '=== Запрос 5. Скалярный подзапрос: товары дороже средней цены ==='
SELECT count(*) AS products_above_avg,
       round((SELECT avg(price) FROM products), 2) AS avg_price
FROM products
WHERE price > (SELECT avg(price) FROM products);

\echo '=== Запрос 5a. Подзапрос с IN: товары из категорий со средней ценой выше 26 000 ==='
SELECT c.name AS category, count(*) AS products_count
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
WHERE p.category_id IN (
    SELECT category_id
    FROM products
    GROUP BY category_id
    HAVING avg(price) > 26000
)
GROUP BY c.name
ORDER BY products_count DESC;

\echo '=== Запрос 5b. Коррелированный EXISTS: покупатели с доставленным заказом ==='
SELECT u.id, u.full_name, u.email
FROM users AS u
WHERE u.role = 'customer'
  AND EXISTS (
      SELECT 1
      FROM orders AS o
      WHERE o.user_id = u.id
        AND o.status = 'delivered'
  )
ORDER BY u.id
LIMIT 10;

\echo '=== Запрос 6. CTE: выручка и средний чек продавцов ==='
WITH seller_sales AS (
    SELECT p.seller_id,
           sum(oi.quantity * oi.unit_price) AS revenue,
           count(DISTINCT o.id)             AS orders_count
    FROM products AS p
    JOIN order_items AS oi ON oi.product_id = p.id
    JOIN orders AS o       ON o.id = oi.order_id
    WHERE o.status IN ('paid', 'shipped', 'delivered')
    GROUP BY p.seller_id
)
SELECT s.store_name,
       ss.orders_count,
       ss.revenue,
       round(ss.revenue / NULLIF(ss.orders_count, 0), 2) AS avg_order_value
FROM seller_sales AS ss
JOIN sellers AS s ON s.id = ss.seller_id
ORDER BY ss.revenue DESC;

\echo '=== Запрос 6a. Рекурсивный CTE: дерево категорий ==='
WITH RECURSIVE category_tree AS (
    SELECT id, parent_id, name, 1 AS level, name::text AS path
    FROM categories
    WHERE parent_id IS NULL
    UNION ALL
    SELECT c.id, c.parent_id, c.name, t.level + 1, t.path || ' / ' || c.name
    FROM categories AS c
    JOIN category_tree AS t ON c.parent_id = t.id
)
SELECT level, path
FROM category_tree
ORDER BY path;

\echo '=== Запрос 7. Представление v_product_catalog ==='
SELECT product_id, title, category_name, seller_name, price, stock_quantity
FROM v_product_catalog
WHERE category_name = 'Смартфоны'
  AND price BETWEEN 10000 AND 50000
ORDER BY price DESC
LIMIT 10;

\echo '=== Запрос 7a. Представление v_seller_revenue ==='
SELECT store_name, orders_count, units_sold, revenue, avg_order_value
FROM v_seller_revenue
ORDER BY revenue DESC
LIMIT 10;

\echo '=== Запрос 7b. Представление v_category_stats ==='
SELECT category_name, products_count, active_products, avg_price, stock_total
FROM v_category_stats
WHERE products_count > 0
ORDER BY avg_price DESC;

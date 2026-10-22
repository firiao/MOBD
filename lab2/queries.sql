-- Лабораторная работа №2. Базовые SQL-запросы и фильтрация данных.
-- Все запросы выполняются к базе marketplace, созданной в лабораторной работе №1
-- и наполненной скриптом seed.sql.
--
-- Запуск:
--   psql -d marketplace -f queries.sql

\echo '=== Запрос 1. DISTINCT: уникальные пары «категория — продавец» ==='
SELECT DISTINCT
       p.category_id AS category,
       c.name        AS category_name,
       p.seller_id   AS seller,
       s.store_name  AS store
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
JOIN sellers    AS s ON s.id = p.seller_id
WHERE p.is_active
ORDER BY category_name, seller
LIMIT 15;

\echo '=== Запрос 2. Фильтрация AND / OR со скобками ==='
SELECT p.id, p.title, p.price, c.name AS category
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
WHERE (p.price < 1000 OR p.price > 45000)
  AND p.is_active
  AND (c.name IN ('Смартфоны', 'Ноутбуки') OR p.seller_id = 1)
ORDER BY p.price DESC
LIMIT 10;

\echo '=== Запрос 3. Предикат BETWEEN ==='
SELECT id, title, price
FROM products
WHERE price BETWEEN 10000 AND 12000
ORDER BY price
LIMIT 10;

\echo '=== Запрос 4. Предикат ILIKE (поиск по шаблону без учёта регистра) ==='
SELECT id, title, price
FROM products
WHERE title ILIKE '%смартфон%'
ORDER BY price DESC
LIMIT 10;

\echo '=== Запрос 5. IS NULL и COALESCE ==='
SELECT id,
       title,
       COALESCE(description, 'Описание не указано') AS description
FROM products
WHERE description IS NULL
ORDER BY id
LIMIT 10;

\echo '=== Запрос 5a. Сравнение с NULL через = не находит строк ==='
SELECT count(*) AS rows_with_eq_null
FROM products
WHERE description = NULL;

\echo '=== Запрос 6. Сортировка по двум столбцам в разных направлениях ==='
SELECT id, title, category_id, price
FROM products
WHERE is_active
  AND price BETWEEN 45000 AND 50000
ORDER BY category_id ASC, price DESC
LIMIT 15;

\echo '=== Запрос 7. Постраничный вывод: страница 1 (LIMIT 10 OFFSET 0) ==='
SELECT id, title, price
FROM products
WHERE is_active
ORDER BY price DESC, id ASC
LIMIT 10 OFFSET 0;

\echo '=== Запрос 7a. Постраничный вывод: страница 3 (LIMIT 10 OFFSET 20) ==='
SELECT id, title, price
FROM products
WHERE is_active
ORDER BY price DESC, id ASC
LIMIT 10 OFFSET 20;

\echo '=== Запрос 8. Трёхзначная логика: сколько строк содержит NULL ==='
SELECT count(*)                        AS total_products,
       count(description)              AS with_description,
       count(*) - count(description)   AS without_description
FROM products;

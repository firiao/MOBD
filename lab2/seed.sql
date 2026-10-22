-- Лабораторная работа №2. Наполнение базы данных маркетплейса тестовыми данными.
-- Скрипт предполагает, что схема из лабораторной работы №1 уже создана (schema.sql).
-- Повторный запуск полностью очищает таблицы и заново заполняет их.
--
-- Запуск:
--   psql -d marketplace -f ../lab1/schema.sql
--   psql -d marketplace -f seed.sql

BEGIN;

TRUNCATE TABLE deliveries, payments, reviews,
               order_items, orders, cart_items, carts,
               stock, products, categories,
               addresses, sellers, users
    RESTART IDENTITY CASCADE;

-- Фиксируем зерно генератора, чтобы данные были воспроизводимыми.
SELECT setseed(0.42);

-- ---------------------------------------------------------------------------
-- 1. Категории: 5 корневых и 15 дочерних (листовых) категорий.
-- ---------------------------------------------------------------------------
INSERT INTO categories (parent_id, name)
VALUES
    (NULL, 'Электроника'),
    (NULL, 'Одежда'),
    (NULL, 'Дом и сад'),
    (NULL, 'Книги'),
    (NULL, 'Спорт');

INSERT INTO categories (parent_id, name)
VALUES
    ((SELECT id FROM categories WHERE name = 'Электроника'), 'Смартфоны'),
    ((SELECT id FROM categories WHERE name = 'Электроника'), 'Ноутбуки'),
    ((SELECT id FROM categories WHERE name = 'Электроника'), 'Наушники'),
    ((SELECT id FROM categories WHERE name = 'Одежда'),     'Куртки'),
    ((SELECT id FROM categories WHERE name = 'Одежда'),     'Джинсы'),
    ((SELECT id FROM categories WHERE name = 'Одежда'),     'Кроссовки'),
    ((SELECT id FROM categories WHERE name = 'Дом и сад'),  'Посуда'),
    ((SELECT id FROM categories WHERE name = 'Дом и сад'),  'Мебель'),
    ((SELECT id FROM categories WHERE name = 'Дом и сад'),  'Растения'),
    ((SELECT id FROM categories WHERE name = 'Книги'),      'Фантастика'),
    ((SELECT id FROM categories WHERE name = 'Книги'),      'Учебники'),
    ((SELECT id FROM categories WHERE name = 'Книги'),      'Детективы'),
    ((SELECT id FROM categories WHERE name = 'Спорт'),      'Велосипеды'),
    ((SELECT id FROM categories WHERE name = 'Спорт'),      'Тренажёры'),
    ((SELECT id FROM categories WHERE name = 'Спорт'),      'Туризм');

-- ---------------------------------------------------------------------------
-- 2. Пользователи: 108 покупателей, 10 продавцов, 1 администратор.
--    id покупателей: 1..108, продавцов: 109..118, администратора: 119.
-- ---------------------------------------------------------------------------
INSERT INTO users (email, password_hash, full_name, phone, role, created_at)
SELECT 'customer' || g || '@example.com',
       md5('password' || g),
       'Покупатель ' || g,
       CASE WHEN g % 4 = 0 THEN NULL
            ELSE '+7-900-' || lpad((1000000 + g)::text, 7, '0') END,
       'customer',
       now() - (g % 365) * interval '1 day'
FROM generate_series(1, 108) AS g;

INSERT INTO users (email, password_hash, full_name, phone, role, created_at)
SELECT 'seller' || g || '@example.com',
       md5('sellerpass' || g),
       'Продавец ' || g,
       '+7-901-' || lpad((2000000 + g)::text, 7, '0'),
       'seller',
       now() - (g * 10) * interval '1 day'
FROM generate_series(1, 10) AS g;

INSERT INTO users (email, password_hash, full_name, phone, role)
VALUES ('admin@example.com', md5('adminpass'), 'Администратор площадки',
        '+7-902-0000000', 'admin');

-- ---------------------------------------------------------------------------
-- 3. Продавцы (магазины). Пользователи 109..118 становятся владельцами.
-- ---------------------------------------------------------------------------
INSERT INTO sellers (user_id, store_name, description, created_at)
SELECT 108 + g,
       'Магазин ' || g,
       'Тестовый магазин-продавец №' || g,
       now() - (g * 10) * interval '1 day'
FROM generate_series(1, 10) AS g;

-- ---------------------------------------------------------------------------
-- 4. Адреса: по одному обязательному адресу у каждого покупателя
--    и второй адрес у каждого десятого.
-- ---------------------------------------------------------------------------
INSERT INTO addresses (user_id, city, street, building, apartment, is_default)
SELECT g,
       (ARRAY['Москва', 'Санкт-Петербург', 'Казань', 'Новосибирск', 'Екатеринбург'])
           [1 + g % 5],
       'ул. Тестовая',
       (g % 100 + 1)::text,
       CASE WHEN g % 3 = 0 THEN NULL ELSE (g % 200 + 1)::text END,
       TRUE
FROM generate_series(1, 108) AS g;

INSERT INTO addresses (user_id, city, street, building, apartment, is_default)
SELECT g, 'Москва', 'ул. Дополнительная', (g % 50 + 1)::text,
       (g % 100 + 1)::text, FALSE
FROM generate_series(10, 108, 10) AS g;

-- ---------------------------------------------------------------------------
-- 5. Товары: 1000 строк. Каждый пятый товар без описания (для IS NULL),
--    каждый двадцатый снят с публикации (is_active = FALSE).
-- ---------------------------------------------------------------------------
WITH leaf AS (
    SELECT array_agg(id   ORDER BY id) AS ids,
           array_agg(name ORDER BY id) AS names
    FROM categories
    WHERE parent_id IS NOT NULL
)
INSERT INTO products (seller_id, category_id, title, description,
                      price, is_active, created_at)
SELECT 1 + (g % 10),
       leaf.ids[1 + (g % array_length(leaf.ids, 1))],
       leaf.names[1 + (g % array_length(leaf.names, 1))] || ' №' || g,
       CASE WHEN g % 5 = 0 THEN NULL
            ELSE 'Описание товара №' || g || '. Гарантия 12 месяцев.' END,
       (100 + random() * 49900)::numeric(12, 2),
       (g % 20 <> 0),
       now() - ((random() * 365)::int) * interval '1 day'
FROM generate_series(1, 1000) AS g
CROSS JOIN leaf;

-- ---------------------------------------------------------------------------
-- 6. Складские остатки: одна строка на товар, 0..500 единиц.
-- ---------------------------------------------------------------------------
INSERT INTO stock (product_id, quantity, updated_at)
SELECT id,
       (random() * 500)::int,
       now() - ((random() * 30)::int) * interval '1 day'
FROM products;

-- ---------------------------------------------------------------------------
-- 7. Корзины первых 50 покупателей и по три позиции в каждой.
-- ---------------------------------------------------------------------------
INSERT INTO carts (user_id, created_at)
SELECT g, now() - (g % 30) * interval '1 day'
FROM generate_series(1, 50) AS g;

INSERT INTO cart_items (cart_id, product_id, quantity)
SELECT c.id,
       1 + ((c.id * 7 + k * 13) % 1000),
       1 + ((c.id + k) % 3)
FROM carts AS c
CROSS JOIN generate_series(1, 3) AS k;

-- ---------------------------------------------------------------------------
-- 8. Заказы: 1000 строк за последние полгода. Адрес берётся из адресов
--    того же покупателя, поэтому ссылочная целостность не нарушается.
-- ---------------------------------------------------------------------------
INSERT INTO orders (user_id, address_id, status, total_amount, created_at)
SELECT 1 + (g % 108),
       (SELECT a.id
        FROM addresses AS a
        WHERE a.user_id = 1 + (g % 108)
        ORDER BY a.is_default DESC, a.id
        LIMIT 1),
       (ARRAY['new', 'new', 'paid', 'paid', 'shipped',
              'shipped', 'delivered', 'delivered', 'cancelled', 'paid'])[1 + (g % 10)],
       0,
       now() - ((random() * 180)::int) * interval '1 day'
FROM generate_series(1, 1000) AS g;

-- По три позиции в каждом заказе. Формула гарантирует уникальность
-- пары (order_id, product_id) внутри заказа.
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT o.id,
       p.id,
       k::int,
       p.price
FROM orders AS o
CROSS JOIN generate_series(1, 3) AS k
JOIN LATERAL (
    SELECT id, price
    FROM products
    WHERE id = 1 + ((o.id * 7 + k * 13) % 1000)
) AS p ON TRUE;

-- Сумма заказа вычисляется из позиций (в схеме это кэшируемое значение).
UPDATE orders AS o
SET total_amount = COALESCE((
    SELECT sum(oi.quantity * oi.unit_price)
    FROM order_items AS oi
    WHERE oi.order_id = o.id
), 0);

-- ---------------------------------------------------------------------------
-- 9. Платежи по оплаченным и завершённым заказам; часть платежей в ожидании.
-- ---------------------------------------------------------------------------
INSERT INTO payments (order_id, method, amount, status, paid_at)
SELECT o.id,
       (ARRAY['card', 'sbp', 'cash_on_delivery'])[1 + (o.id % 3)],
       o.total_amount,
       CASE WHEN o.id % 11 = 0 THEN 'pending'
            WHEN o.status = 'cancelled' THEN 'refunded'
            ELSE 'succeeded' END,
       CASE WHEN o.id % 11 = 0 THEN NULL
            ELSE o.created_at + interval '5 minutes' END
FROM orders AS o
WHERE o.status <> 'new';

-- ---------------------------------------------------------------------------
-- 10. Отзывы: 500 отзывов, по одному на разные товары.
-- ---------------------------------------------------------------------------
INSERT INTO reviews (user_id, product_id, rating, body, created_at)
SELECT 1 + (g % 108),
       g,
       1 + (g % 5),
       CASE WHEN g % 6 = 0 THEN NULL ELSE 'Отзыв №' || g END,
       now() - (g % 120) * interval '1 day'
FROM generate_series(1, 500) AS g;

-- ---------------------------------------------------------------------------
-- 11. Доставки для оплаченных, отправленных и доставленных заказов.
-- ---------------------------------------------------------------------------
INSERT INTO deliveries (order_id, address_id, carrier, track_number,
                        status, shipped_at, delivered_at)
SELECT o.id,
       o.address_id,
       (ARRAY['СДЭК', 'Почта России', 'Boxberry', 'Яндекс Доставка'])[1 + (o.id % 4)],
       'TRK' || lpad(o.id::text, 8, '0'),
       CASE WHEN o.status = 'delivered' THEN 'delivered'
            WHEN o.status = 'shipped'   THEN 'in_transit'
            ELSE 'waiting' END,
       CASE WHEN o.status IN ('shipped', 'delivered')
            THEN o.created_at + interval '1 day' END,
       CASE WHEN o.status = 'delivered'
            THEN o.created_at + interval '3 days' END
FROM orders AS o
WHERE o.status IN ('paid', 'shipped', 'delivered');

COMMIT;

ANALYZE;

-- Контрольные количества строк.
SELECT 'users' AS table_name, count(*) FROM users
UNION ALL SELECT 'sellers',       count(*) FROM sellers
UNION ALL SELECT 'categories',    count(*) FROM categories
UNION ALL SELECT 'products',      count(*) FROM products
UNION ALL SELECT 'stock',         count(*) FROM stock
UNION ALL SELECT 'orders',        count(*) FROM orders
UNION ALL SELECT 'order_items',   count(*) FROM order_items
UNION ALL SELECT 'payments',      count(*) FROM payments
UNION ALL SELECT 'reviews',       count(*) FROM reviews
UNION ALL SELECT 'deliveries',    count(*) FROM deliveries
UNION ALL SELECT 'addresses',     count(*) FROM addresses
UNION ALL SELECT 'carts',         count(*) FROM carts
UNION ALL SELECT 'cart_items',    count(*) FROM cart_items
ORDER BY table_name;

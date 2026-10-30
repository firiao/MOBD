# Лабораторная работа №3. Многотабличные запросы и аналитические представления

## Цель работы

Составить набор многотабличных и аналитических запросов к базе данных маркетплейса: соединения `JOIN`, агрегация и `GROUP BY`/`HAVING`, подзапросы, CTE (включая рекурсивный) и аналитические представления.

## 1. Исходные данные и запуск

Используется схема лабораторной работы №1 и данные лабораторной работы №2. Представления создаются скриптом [`views.sql`](views.sql), запросы находятся в [`queries.sql`](queries.sql), полный вывод — в [`results.txt`](results.txt).

```bash
psql -d marketplace -f views.sql
psql -d marketplace -f queries.sql
```

Созданные представления:

| Представление | Назначение |
|---|---|
| `v_product_catalog` | каталог: товар, категория, продавец, цена, остаток |
| `v_seller_revenue` | выручка, число заказов, проданные единицы и средний чек по продавцам |
| `v_category_stats` | количество товаров, активные товары, средняя/минимальная/максимальная цена, остаток по категориям |

## 2. Запросы

### Запрос 1. `INNER JOIN` трёх таблиц: товар — категория — продавец

**Назначение:** показать активные товары вместе с названием категории и магазином-продавцом.

```sql
SELECT p.id, p.title, c.name AS category, s.store_name AS seller, p.price
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
JOIN sellers    AS s ON s.id = p.seller_id
WHERE p.is_active
ORDER BY p.price DESC
LIMIT 12;
```

Фрагмент результата:

```text
 id  |      title      |  category  |   seller   |  price
-----+-----------------+------------+------------+----------
 298 | Тренажёры №298  | Тренажёры  | Магазин 9  | 49987.42
 393 | Куртки №393     | Куртки     | Магазин 4  | 49978.32
 452 | Наушники №452   | Наушники   | Магазин 3  | 49921.07
 454 | Джинсы №454     | Джинсы     | Магазин 5  | 49920.62
 962 | Наушники №962   | Наушники   | Магазин 3  | 49894.72
 875 | Кроссовки №875  | Кроссовки  | Магазин 6  | 49839.20
  76 | Ноутбуки №76    | Ноутбуки   | Магазин 7  | 49821.50
 975 | Смартфоны №975  | Смартфоны  | Магазин 6  | 49798.82
 192 | Велосипеды №192 | Велосипеды | Магазин 3  | 49779.20
 637 | Мебель №637     | Мебель     | Магазин 8  | 49755.16
 159 | Фантастика №159 | Фантастика | Магазин 10 | 49727.16
 644 | Туризм №644     | Туризм     | Магазин 5  | 49700.36
(12 rows)
```

Условие соединения задано по внешним ключам `products.category_id` и `products.seller_id`.

### Запрос 2. `LEFT JOIN`: товары без отзывов

**Назначение:** найти товары, для которых в таблице `reviews` нет ни одной связанной строки. `LEFT JOIN` сохраняет товары, а `HAVING count(r.id) = 0` оставляет только те, где совпадений не было.

```sql
SELECT p.id, p.title, count(r.id) AS reviews_count
FROM products AS p
LEFT JOIN reviews AS r ON r.product_id = p.id
GROUP BY p.id, p.title
HAVING count(r.id) = 0
ORDER BY p.id
LIMIT 12;
```

Фрагмент результата:

```text
 id  |      title      | reviews_count
-----+-----------------+---------------
 501 | Посуда №501     |             0
 502 | Мебель №502     |             0
 503 | Растения №503   |             0
 504 | Фантастика №504 |             0
 505 | Учебники №505   |             0
 506 | Детективы №506  |             0
 507 | Велосипеды №507 |             0
 508 | Тренажёры №508  |             0
 509 | Туризм №509     |             0
 510 | Смартфоны №510  |             0
 511 | Ноутбуки №511   |             0
 512 | Наушники №512   |             0
(12 rows)
```

Если заменить `LEFT JOIN` на `INNER JOIN`, товары без отзывов исчезнут из результата.

### Запрос 3. `GROUP BY`: количество товаров и средняя цена по категориям

**Назначение:** получить сводку по активным товарам в разрезе категорий.

```sql
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
```

Фрагмент результата:

```text
  category  | products_count | avg_price | min_price | max_price
------------+----------------+-----------+-----------+-----------
 Ноутбуки   |             67 |  27677.10 |    597.06 |  49821.50
 Смартфоны  |             50 |  27608.84 |    132.26 |  49798.82
 Мебель     |             67 |  27115.28 |   1080.10 |  49755.16
 Тренажёры  |             66 |  26995.24 |   1094.00 |  49987.42
 Наушники   |             67 |  26919.00 |    513.05 |  49921.07
 Фантастика |             67 |  26453.00 |    439.42 |  49727.16
 Туризм     |             66 |  25498.03 |    660.43 |  49700.36
 Велосипеды |             66 |  25474.88 |    927.17 |  49779.20
 Посуда     |             67 |  25389.95 |   2479.55 |  48440.16
 Учебники   |             50 |  25055.31 |   1410.09 |  49634.40
 Куртки     |             67 |  24833.51 |    402.95 |  49978.32
 Джинсы     |             67 |  24487.66 |   1185.41 |  49920.62
 Кроссовки  |             50 |  24033.19 |    646.03 |  49839.20
 Растения   |             67 |  23434.78 |   1571.62 |  45868.69
 Детективы  |             66 |  23131.81 |    185.51 |  49376.23
(15 rows)
```

В списке выборки присутствуют только столбцы из `GROUP BY` и агрегатные функции.

### Запрос 4. `HAVING`: продавцы с выручкой выше 10 млн

**Назначение:** отфильтровать уже сгруппированные данные по результату агрегации. `WHERE` здесь фильтрует исходные заказы до группировки, а `HAVING` — итоговую выручку.

```sql
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
```

Результат:

```text
 store_name | orders_count | units_sold |   revenue
------------+--------------+------------+-------------
 Магазин 3  |          300 |        600 | 15798337.98
 Магазин 10 |          300 |        600 | 15295305.54
 Магазин 9  |          300 |        600 | 15161473.74
 Магазин 6  |          300 |        600 | 14718663.78
 Магазин 2  |          200 |        500 | 12395479.40
(5 rows)
```

Магазин 4 с выручкой около 9,95 млн в результат не попал.

### Запрос 5. Скалярный подзапрос

**Назначение:** посчитать товары, цена которых выше средней по всей таблице. Подзапрос возвращает ровно одно значение и вычисляется один раз.

```sql
SELECT count(*) AS products_above_avg,
       round((SELECT avg(price) FROM products), 2) AS avg_price
FROM products
WHERE price > (SELECT avg(price) FROM products);
```

```text
 products_above_avg | avg_price
--------------------+-----------
                512 |  25575.85
(1 row)
```

### Запрос 5a. Подзапрос с `IN`

**Назначение:** найти товары из категорий, средняя цена которых выше 26 000 ₽.

```sql
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
```

```text
  category  | products_count
------------+----------------
 Фантастика |             67
 Мебель     |             67
 Ноутбуки   |             67
 Наушники   |             67
 Смартфоны  |             66
 Тренажёры  |             66
(6 rows)
```

### Запрос 5b. Коррелированный `EXISTS`

**Назначение:** вывести покупателей, у которых есть хотя бы один доставленный заказ. Подзапрос ссылается на `u.id` внешнего запроса.

```sql
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
```

```text
 id |   full_name   |         email
----+---------------+------------------------
  1 | Покупатель 1  | customer1@example.com
  2 | Покупатель 2  | customer2@example.com
  3 | Покупатель 3  | customer3@example.com
  4 | Покупатель 4  | customer4@example.com
  5 | Покупатель 5  | customer5@example.com
  6 | Покупатель 6  | customer6@example.com
  7 | Покупатель 7  | customer7@example.com
  8 | Покупатель 8  | customer8@example.com
  9 | Покупатель 9  | customer9@example.com
 10 | Покупатель 10 | customer10@example.com
(10 rows)
```

### Запрос 6. CTE: выручка и средний чек продавцов

**Назначение:** разбить сложный запрос на два логических шага. В CTE `seller_sales` считается выручка и число заказов, во внешнем запросе добавляются данные магазина и средний чек.

```sql
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
```

Фрагмент результата:

```text
 store_name | orders_count |   revenue   | avg_order_value
------------+--------------+-------------+-----------------
 Магазин 3  |          300 | 15798337.98 |        52661.13
 Магазин 10 |          300 | 15295305.54 |        50984.35
 Магазин 9  |          300 | 15161473.74 |        50538.25
 Магазин 6  |          300 | 14718663.78 |        49062.21
 Магазин 2  |          200 | 12395479.40 |        61977.40
 Магазин 4  |          200 |  9954994.40 |        49774.97
 Магазин 7  |          200 |  7809288.18 |        39046.44
 Магазин 5  |          100 |  7640030.73 |        76400.31
 Магазин 1  |          100 |  5254711.96 |        52547.12
 Магазин 8  |          100 |  2668582.68 |        26685.83
(10 rows)
```

### Запрос 6a. Рекурсивный CTE: дерево категорий

**Назначение:** обойти иерархию `categories.parent_id → categories.id`, начиная с корневых категорий, и построить путь от корня.

```sql
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
```

Фрагмент результата:

```text
 level |          path
-------+-------------------------
     1 | Дом и сад
     2 | Дом и сад / Мебель
     2 | Дом и сад / Посуда
     2 | Дом и сад / Растения
     1 | Книги
     2 | Книги / Детективы
     2 | Книги / Учебники
     2 | Книги / Фантастика
     1 | Одежда
     2 | Одежда / Джинсы
     2 | Одежда / Кроссовки
     2 | Одежда / Куртки
     1 | Спорт
     2 | Спорт / Велосипеды
     2 | Спорт / Тренажёры
     2 | Спорт / Туризм
     1 | Электроника
     2 | Электроника / Наушники
     2 | Электроника / Ноутбуки
     2 | Электроника / Смартфоны
(20 rows)
```

Рекурсивная часть соединяет дочернюю категорию с уже найденным родителем и увеличивает уровень.

### Запрос 7. Обращение к представлению `v_product_catalog`

```sql
SELECT product_id, title, category_name, seller_name, price, stock_quantity
FROM v_product_catalog
WHERE category_name = 'Смартфоны'
  AND price BETWEEN 10000 AND 50000
ORDER BY price DESC
LIMIT 10;
```

```text
 product_id |     title      | category_name | seller_name |  price   | stock_quantity
------------+----------------+---------------+-------------+----------+----------------
        975 | Смартфоны №975 | Смартфоны     | Магазин 6   | 49798.82 |            394
         90 | Смартфоны №90  | Смартфоны     | Магазин 1   | 48897.04 |            477
        435 | Смартфоны №435 | Смартфоны     | Магазин 6   | 47957.89 |             24
         60 | Смартфоны №60  | Смартфоны     | Магазин 1   | 47856.03 |            293
        270 | Смартфоны №270 | Смартфоны     | Магазин 1   | 46750.97 |            285
         30 | Смартфоны №30  | Смартфоны     | Магазин 1   | 45250.24 |             27
        885 | Смартфоны №885 | Смартфоны     | Магазин 6   | 45058.21 |            296
        615 | Смартфоны №615 | Смартфоны     | Магазин 6   | 44637.09 |            442
        315 | Смартфоны №315 | Смартфоны     | Магазин 6   | 43204.26 |            403
        195 | Смартфоны №195 | Смартфоны     | Магазин 6   | 42756.66 |            231
(10 rows)
```

### Запрос 7a. Обращение к представлению `v_seller_revenue`

```sql
SELECT store_name, orders_count, units_sold, revenue, avg_order_value
FROM v_seller_revenue
ORDER BY revenue DESC
LIMIT 10;
```

Фрагмент результата:

```text
 store_name | orders_count | units_sold |   revenue   | avg_order_value
------------+--------------+------------+-------------+-----------------
 Магазин 3  |          300 |        600 | 15798337.98 |        52661.13
 Магазин 10 |          300 |        600 | 15295305.54 |        50984.35
 Магазин 9  |          300 |        600 | 15161473.74 |        50538.25
 Магазин 6  |          300 |        600 | 14718663.78 |        49062.21
 Магазин 2  |          200 |        500 | 12395479.40 |        61977.40
 Магазин 4  |          200 |        400 |  9954994.40 |        49774.97
 Магазин 7  |          200 |        300 |  7809288.18 |        39046.44
 Магазин 5  |          100 |        300 |  7640030.73 |        76400.31
 Магазин 1  |          100 |        200 |  5254711.96 |        52547.12
 Магазин 8  |          100 |        100 |  2668582.68 |        26685.83
(10 rows)
```

### Запрос 7b. Обращение к представлению `v_category_stats`

```sql
SELECT category_name, products_count, active_products, avg_price, stock_total
FROM v_category_stats
WHERE products_count > 0
ORDER BY avg_price DESC;
```

Фрагмент результата:

```text
 category_name | products_count | active_products | avg_price | stock_total
---------------+----------------+-----------------+-----------+-------------
 Ноутбуки      |             67 |              67 |  27677.10 |       16599
 Смартфоны     |             66 |              50 |  27161.76 |       15572
 Мебель        |             67 |              67 |  27115.28 |       17293
 Тренажёры     |             66 |              66 |  26995.24 |       15706
 Наушники      |             67 |              67 |  26919.00 |       16831
 Фантастика    |             67 |              67 |  26453.00 |       15956
 Туризм        |             66 |              66 |  25498.03 |       17107
 Велосипеды    |             66 |              66 |  25474.88 |       16093
(8 rows)
```

## 3. Выводы

В работе использованы все основные способы соединения и агрегации:

- `INNER JOIN` объединяет только строки с совпадениями по внешним ключам;
- `LEFT JOIN` позволяет увидеть отсутствие связанных строк (товары без отзывов);
- `GROUP BY` и `HAVING` дают сводные показатели и фильтрацию групп;
- скалярный подзапрос, `IN` и коррелированный `EXISTS` решают разные классы задач;
- CTE упрощает многошаговый расчёт, рекурсивный CTE обходит дерево категорий;
- представления скрывают сложные соединения и дают готовые витрины для отчётов.

Обычные представления не хранят данные: при каждом обращении выполняется сохранённый `SELECT`, поэтому отчёты всегда показывают актуальное состояние базы.

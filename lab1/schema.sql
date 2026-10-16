BEGIN;

DROP TABLE IF EXISTS deliveries, payments, reviews,
    order_items, orders, cart_items, carts,
    stock, products, categories,
    addresses, sellers, users CASCADE;

CREATE TABLE users (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email         TEXT        NOT NULL UNIQUE,
    password_hash TEXT        NOT NULL,
    full_name     TEXT        NOT NULL,
    phone         VARCHAR(20),
    role          TEXT        NOT NULL DEFAULT 'customer'
                  CHECK (role IN ('customer', 'seller', 'admin')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE sellers (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT      NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    store_name  TEXT        NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE addresses (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT  NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    city       TEXT    NOT NULL,
    street     TEXT    NOT NULL,
    building   TEXT    NOT NULL,
    apartment  TEXT,
    is_default BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE categories (
    id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id BIGINT REFERENCES categories(id) ON DELETE RESTRICT,
    name      TEXT   NOT NULL,
    UNIQUE (parent_id, name)
);

CREATE UNIQUE INDEX categories_root_name_uniq
    ON categories (name) WHERE parent_id IS NULL;

CREATE TABLE products (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id   BIGINT        NOT NULL REFERENCES sellers(id)    ON DELETE RESTRICT,
    category_id BIGINT        NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    title       TEXT          NOT NULL,
    description TEXT,
    price       NUMERIC(12,2) NOT NULL CHECK (price > 0),
    is_active   BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE stock (
    product_id BIGINT      PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE,
    quantity   INTEGER     NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE carts (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE cart_items (
    cart_id    BIGINT  NOT NULL REFERENCES carts(id)    ON DELETE CASCADE,
    product_id BIGINT  NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity   INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (cart_id, product_id)
);

CREATE TABLE orders (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id      BIGINT        NOT NULL REFERENCES users(id)     ON DELETE RESTRICT,
    address_id   BIGINT        NOT NULL REFERENCES addresses(id) ON DELETE RESTRICT,
    status       TEXT          NOT NULL DEFAULT 'new'
                 CHECK (status IN ('new','paid','shipped','delivered','cancelled')),
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    created_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE order_items (
    order_id   BIGINT        NOT NULL REFERENCES orders(id)   ON DELETE CASCADE,
    product_id BIGINT        NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity   INTEGER       NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price > 0),
    PRIMARY KEY (order_id, product_id)
);

CREATE TABLE payments (
    id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT        NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
    method   TEXT          NOT NULL CHECK (method IN ('card','sbp','cash_on_delivery')),
    amount   NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    status   TEXT          NOT NULL DEFAULT 'pending'
             CHECK (status IN ('pending','succeeded','failed','refunded')),
    paid_at  TIMESTAMPTZ
);

CREATE TABLE reviews (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
    product_id BIGINT      NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    rating     INTEGER     NOT NULL CHECK (rating BETWEEN 1 AND 5),
    body       TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, product_id)
);

CREATE TABLE deliveries (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id     BIGINT      NOT NULL UNIQUE REFERENCES orders(id)    ON DELETE CASCADE,
    address_id   BIGINT      NOT NULL        REFERENCES addresses(id) ON DELETE RESTRICT,
    carrier      TEXT        NOT NULL,
    track_number TEXT        UNIQUE,
    status       TEXT        NOT NULL DEFAULT 'waiting'
                 CHECK (status IN ('waiting','in_transit','delivered','returned')),
    shipped_at   TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ
);

COMMIT;

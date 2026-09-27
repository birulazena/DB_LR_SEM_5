# Даталогическая модель базы данных (Третья нормальная форма — 3NF)

Все первичные ключи имеют тип `UUID` и генерируются на стороне бэкенда (`Kotlin: UUID.randomUUID()`).
Модель включает паттерн **Soft Delete** (`is_deleted = false`) для сохранения целостности связей.

---

## 1. Спецификация сущностей

### 1. `users` (Учетные записи)
* `id` (UUID, PK) — первичный ключ.
* `email` (VARCHAR(150), UNIQUE, NOT NULL) — логин.
* `password_hash` (VARCHAR(255), NOT NULL) — хэш пароля.
* `is_active` (BOOLEAN, NOT NULL, DEFAULT true) — статус блокировки.
* `is_deleted` (BOOLEAN, NOT NULL, DEFAULT false) — флаг мягкого удаления.
* `created_at` (TIMESTAMPTZ, NOT NULL, DEFAULT CURRENT_TIMESTAMP).

### 2. `user_profiles` (Профили пользователей)
* `id` (UUID, PK) — первичный ключ.
* `user_id` (UUID, UNIQUE, NOT NULL, FK -> `users.id`) — ссылка на пользователя.
* `first_name` (VARCHAR(100), NOT NULL) — имя.
* `last_name` (VARCHAR(100), NOT NULL) — фамилия.
* `phone` (VARCHAR(30), UNIQUE, NOT NULL) — телефон.
> **Тип связи:** 1:1 с таблицей `users` (обеспечивается `UNIQUE` на `user_id`).

### 3. `roles` (Роли-контейнеры)
* `id` (UUID, PK) — первичный ключ.
* `name` (VARCHAR(50), UNIQUE, NOT NULL) — имя роли (`ROLE_ADMIN`, `ROLE_DISPATCHER`, `ROLE_DRIVER`, `ROLE_CLIENT`).
* `description` (VARCHAR(255), NULL) — описание.

### 4. `permissions` (Разрешения)
* `id` (UUID, PK) — первичный ключ.
* `code` (VARCHAR(100), UNIQUE, NOT NULL) — код права (`orders:create`, `shipments:update`).
* `description` (VARCHAR(255), NULL) — назначение права.

### 5. `user_roles` (Таблица связи ролей и пользователей)
* `user_id` (UUID, NOT NULL, FK -> `users.id`)
* `role_id` (UUID, NOT NULL, FK -> `roles.id`)
* *PRIMARY KEY (`user_id`, `role_id`)*.
> **Тип связи:** Чистая M:N связка.

### 6. `role_permissions` (Таблица связи ролей и разрешений)
* `role_id` (UUID, NOT NULL, FK -> `roles.id`)
* `permission_id` (UUID, NOT NULL, FK -> `permissions.id`)
* *PRIMARY KEY (`role_id`, `permission_id`)*.
> **Тип связи:** Чистая M:N связка.

### 7. `warehouses` (Склады и терминалы)
* `id` (UUID, PK) — первичный ключ.
* `name` (VARCHAR(100), NOT NULL) — наименование склада.
* `address` (VARCHAR(255), NOT NULL) — физический адрес.
* `is_deleted` (BOOLEAN, NOT NULL, DEFAULT false) — флаг мягкого удаления.

### 8. `vehicles` (Транспортные средства)
* `id` (UUID, PK) — первичный ключ.
* `license_plate` (VARCHAR(20), UNIQUE, NOT NULL) — госномер.
* `model` (VARCHAR(100), NOT NULL) — марка и модель.
* `max_weight_kg` (NUMERIC(10, 2), NOT NULL) — грузоподъемность.
* `current_warehouse_id` (UUID, NULL, FK -> `warehouses.id`) — текущий склад базирования.
* `is_deleted` (BOOLEAN, NOT NULL, DEFAULT false).
> **Тип связи:** 1:M (`warehouses` 1 -> M `vehicles`).

### 9. `orders` (Заказы на грузоперевозку)
* `id` (UUID, PK) — первичный ключ.
* `order_number` (VARCHAR(50), UNIQUE, NOT NULL) — трек-номер.
* `customer_id` (UUID, NOT NULL, FK -> `users.id`) — заказчик перевозки.
* `origin_warehouse_id` (UUID, NOT NULL, FK -> `warehouses.id`) — пункт отправления.
* `destination_warehouse_id` (UUID, NOT NULL, FK -> `warehouses.id`) — пункт выдачи.
* `total_cost` (NUMERIC(10, 2), NOT NULL, DEFAULT 0.00) — расчетная стоимость.
* `status` (VARCHAR(30), NOT NULL, DEFAULT 'CREATED') — статус (`CREATED`, `IN_TRANSIT`, `DELIVERED`, `CANCELLED`).
* `is_deleted` (BOOLEAN, NOT NULL, DEFAULT false).
* `created_at` (TIMESTAMPTZ, NOT NULL, DEFAULT CURRENT_TIMESTAMP).
> **Тип связи:** 1:M (`users` 1 -> M `orders`, `warehouses` 1 -> M `orders`).

### 10. `cargo_items` (Грузовые места заказа)
* `id` (UUID, PK) — первичный ключ.
* `order_id` (UUID, NOT NULL, FK -> `orders.id`) — ссылка на заказ.
* `name` (VARCHAR(150), NOT NULL) — описание места (например, «Поддон строительных смесей»).
* `quantity` (INT, NOT NULL, DEFAULT 1) — количество идентичных мест.
* `weight_kg` (NUMERIC(10, 2), NOT NULL) — масса одного места.
* `volume_m3` (NUMERIC(10, 3), NOT NULL) — объем одного места.
> **Тип связи:** 1:M (`orders` 1 -> M `cargo_items`).

### 11. `shipments` (Консолидированные рейсы)
* `id` (UUID, PK) — первичный ключ.
* `shipment_code` (VARCHAR(50), UNIQUE, NOT NULL) — номер путевого листа.
* `vehicle_id` (UUID, NOT NULL, FK -> `vehicles.id`) — автомобиль.
* `driver_id` (UUID, NOT NULL, FK -> `users.id`) — водитель.
* `status` (VARCHAR(30), NOT NULL, DEFAULT 'PLANNED') — статус (`PLANNED`, `ON_ROUTE`, `COMPLETED`).
* `planned_arrival` (TIMESTAMPTZ, NOT NULL) — расчетная дата прибытия.
* `is_deleted` (BOOLEAN, NOT NULL, DEFAULT false).
> **Тип связи:** 1:M (`vehicles` 1 -> M `shipments`, `users` 1 -> M `shipments`).

### 12. `shipment_orders` (Заказы в рейсе — M:N сущность с полезной нагрузкой)
* `id` (UUID, PK) — суррогатный ключ связи.
* `shipment_id` (UUID, NOT NULL, FK -> `shipments.id`) — рейс.
* `order_id` (UUID, NOT NULL, FK -> `orders.id`) — заказ.
* `is_delivered` (BOOLEAN, NOT NULL, DEFAULT false) — статус выдачи конкретного заказа в рамках рейса.
* *UNIQUE (`shipment_id`, `order_id`)*.
> **Тип связи:** M:N между рейсами и заказами (несет бизнес-атрибут `is_delivered`).

### 13. `audit_logs` (Журнал аудита действий)
* `id` (UUID, PK) — первичный ключ.
* `user_id` (UUID, NOT NULL, FK -> `users.id`) — автор операции (всегда заполнен).
* `action` (VARCHAR(50), NOT NULL) — действие (`STATUS_UPDATE`, `SOFT_DELETE`, `ORDER_CREATE`).
* `entity_name` (VARCHAR(50), NOT NULL) — затронутая сущность (`orders`, `shipments`, `users`).
* `entity_id` (UUID, NOT NULL) — ID модифицированной записи.
* `details` (VARCHAR(255), NOT NULL) — краткая текстовая суть изменений.
* `created_at` (TIMESTAMPTZ, NOT NULL, DEFAULT CURRENT_TIMESTAMP).
> **Тип связи:** 1:M (`users` 1 -> M `audit_logs`).

---

## 2. Сводка представленных типов связей
1. **1:1:** `users` $\leftrightarrow$ `user_profiles` (один аккаунт строго соответствует одному профилю).
2. **1:M:**
    * `orders` $\rightarrow$ `cargo_items` (один заказ содержит много позиций груза).
    * `warehouses` $\rightarrow$ `vehicles` (на складе базируется автопарк).
    * `users` $\rightarrow$ `orders` (клиент оформляет множество заказов).
    * `users` $\rightarrow$ `audit_logs` (пользователь порождает записи журнала).
3. **M:N:**
    * `users` $\leftrightarrow$ `roles` (через `user_roles`).
    * `roles` $\leftrightarrow$ `permissions` (через `role_permissions`).
    * `shipments` $\leftrightarrow$ `orders` (через `shipment_orders` с фиксацией факта доставки `is_delivered`).

---
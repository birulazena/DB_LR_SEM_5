# Даталогическая модель базы данных (Третья нормальная форма — 3NF)

Все первичные ключи имеют тип `UUID` и генерируются на стороне бэкенда (`Kotlin: UUID.randomUUID()`).
Модель включает паттерн **Soft Delete** (`is_deleted = false`) для сохранения целостности связей.

---

## 1. Спецификация сущностей

### 1. `users` (Учетные записи)
* `id` (UUID, PK) — первичный ключ.
* `email` (VARCHAR(150), NOT NULL) — логин.
* `password_hash` (VARCHAR(255), NOT NULL) — хэш пароля.
* `is_active` (BOOLEAN, NOT NULL, DEFAULT true) — статус блокировки.
* `is_deleted` (BOOLEAN, NOT NULL, DEFAULT false) — флаг мягкого удаления.
* `created_at` (TIMESTAMPTZ, NOT NULL, DEFAULT CURRENT_TIMESTAMP).

### 2. `user_profiles` (Профили пользователей)
* `id` (UUID, PK) — первичный ключ.
* `user_id` (UUID, UNIQUE, NOT NULL, FK -> `users.id`) — ссылка на пользователя.
* `first_name` (VARCHAR(100), NOT NULL) — имя.
* `last_name` (VARCHAR(100), NOT NULL) — фамилия.
* `phone` (VARCHAR(30), NOT NULL) — телефон.
* `is_deleted` (BOOLEAN, NOT NULL, DEFAULT false) — флаг мягкого удаления
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
* `license_plate` (VARCHAR(20), NOT NULL) — госномер.
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

---

## 3. Стратегия индексации

### 3.1. Автоматические индексы СУБД
* **Первичные ключи:** автоматически создаются для всех 13 таблиц по полю `id` (или составному ключу связующих таблиц).
* **Ограничения уникальности:**
   * `user_profiles(user_id)` *(гарантирует связь 1:1)*
   * `roles(name)`
   * `permissions(code)`
   * `orders(order_number)`
   * `shipments(shipment_code)`
   * `shipment_orders(shipment_id, order_id)`

---

### 3.2. Обязательные пользовательские индексы для внешних ключей

1.**`idx_orders_customer_id`** на `orders(customer_id)` — выборка заказов конкретного клиента в личном кабинете.
2.**`idx_orders_origin_warehouse_id`** на `orders(origin_warehouse_id)` — логистика отправления со склада.
3.**`idx_orders_destination_warehouse_id`** на `orders(destination_warehouse_id)` — логистика прибытия на склад.
4.**`idx_cargo_items_order_id`** на `cargo_items(order_id)` — получение состава груза при просмотре заказа (`JOIN orders -> cargo_items`).
5.**`idx_shipments_vehicle_id`** на `shipments(vehicle_id)` — история рейсов автомобиля.
6.**`idx_shipments_driver_id`** на `shipments(driver_id)` — путевые листы конкретного водителя.
7.**`idx_shipment_orders_order_id`** на `shipment_orders(order_id)` — обратный поиск: в какой рейс включен конкретный заказ. *(Примечание: поиск по `shipment_id` уже ускорен за счет уникального составного ограничения).*
8.**`idx_audit_logs_user_id`** на `audit_logs(user_id)` — журнал действий конкретного пользователя.
9.**`idx_user_roles_role_id`** на `user_roles(role_id)` — быстрое получение пользователей по роли.

---

### 3.3. Специализированные и составные бизнес-индексы
Для оптимизации частых аналитических выборок, фильтрации и пагинации создаются следующие индексы:

1. **`idx_orders_status_active`:**
   * `CREATE INDEX idx_orders_status_active ON orders(status) WHERE is_deleted = false;`
   * *Обоснование:* 99% оперативных запросов диспетчера ищут активные заказы по статусу. Удаленные заказы исключаются из индекса, экономя память RAM (Buffer Cache).
2. **`idx_audit_logs_entity`:**
   * `CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_name, entity_id);`
   * *Обоснование:* Просмотр истории изменений конкретного объекта (например, история заказа `entity_name = 'orders' AND entity_id = '...'`).
3. **`idx_audit_logs_created_at`:**
   * `CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);`
   * *Обоснование:* Сортировка ленты аудита от самых свежих событий к старым.
4. **`idx_users_unique_active_email`:**
    * `CREATE UNIQUE INDEX idx_users_unique_active_email ON users(email) WHERE is_deleted = false;`
    * *Обоснование:* Поддержка Soft Delete: позволяет повторную регистрацию на тот же email после удаления.
5. **`idx_profiles_unique_active_phone`:**
    * `CREATE UNIQUE INDEX idx_profiles_unique_active_phone ON user_profiles(phone) WHERE is_deleted = false;`
6. **`idx_users_created_at_desc`:**
    * `CREATE INDEX idx_users_created_at_desc ON users(created_at DESC) WHERE is_deleted = false;`
    * *Обоснование:* Устраняет файловую сортировку при пагинации пользователей в админке.
7. **GIN-индексы поиска (расширение `pg_trgm`):**
    * `CREATE EXTENSION IF NOT EXISTS pg_trgm;`
    * Поиск по email: `idx_users_email_trgm ON users USING gin (email gin_trgm_ops) WHERE is_deleted = false;`
    * Поиск по ФИО: `idx_profiles_names_trgm ON user_profiles USING gin (first_name gin_trgm_ops, last_name gin_trgm_ops) WHERE is_deleted = false;`
    * Поиск по телефону: `idx_profiles_phone_trgm ON user_profiles USING gin (phone gin_trgm_ops) WHERE is_deleted = false;`
8. **`idx_warehouses_active_name_id`**:
    * `CREATE INDEX idx_warehouses_active_name_id ON warehouses(name ASC, id ASC) WHERE is_deleted = false;`
    * *Обоснование:* Обеспечивает индексное сканирование (Index Scan) при постраничной выборке складов по названию с детерминированным тай-брейкером `id` без затратной операции сортировки в памяти (Sort Node).
9. **`idx_vehicles_active_filters`**:
    * `CREATE INDEX idx_vehicles_active_filters ON vehicles(current_warehouse_id, max_weight_kg) WHERE is_deleted = false;`
    * *Обоснование:* Составной индекс для моментальной фильтрации автопарка по складу базирования и минимальной грузоподъемности при планировании рейса.
10. **GIN-индекс поиска по модели ТС (`pg_trgm`):**
* `CREATE INDEX idx_vehicles_model_trgm ON vehicles USING gin (model gin_trgm_ops) WHERE is_deleted = false;`
* *Обоснование:* Поддержка быстрого нечеткого поиска автомобиля по марке/модели диспетчером (`ILIKE '%Volvo%'`).
11. **`idx_warehouses_unique_active_address`**:
    * `CREATE UNIQUE INDEX idx_warehouses_unique_active_address ON warehouses(address) WHERE is_deleted = false;`
    * *Обоснование:* Гарантирует уникальность адресов только среди действующих складов, допуская повторное использование адреса после Soft Delete.
12. **`idx_vehicles_unique_active_plate`**:
    * `CREATE UNIQUE INDEX idx_vehicles_unique_active_plate ON vehicles(license_plate) WHERE is_deleted = false;`
    * *Обоснование:* Обеспечивает уникальность госномера среди активных ТС, допуская повторную регистрацию номера после списания (Soft Delete).
13. **`idx_vehicles_active_model_id`**:
    * `CREATE INDEX idx_vehicles_active_model_id ON vehicles(model ASC, id ASC) WHERE is_deleted = false;`
    * *Обоснование:* B-Tree индекс для детерминированной постраничной выборки (пагинации) автопарка по названию модели и `id`. В отличие от GIN-индекса, позволяет избежать фазы сортировки в памяти (`Sort Node`).
14. **`idx_orders_created_at_desc`**:
    * `CREATE INDEX idx_orders_created_at_desc ON orders(created_at DESC) WHERE is_deleted = false;`
    * *Обоснование:* Устраняет ресурсоемкую операцию сортировки в оперативной памяти (`Sort Node`) при постраничном выводе глобального диспетчерского журнала заказов.
15. **`idx_orders_customer_active_created`**:
    * `CREATE INDEX idx_orders_customer_active_created ON orders(customer_id, created_at DESC) WHERE is_deleted = false;`
    * *Обоснование:* Составной частичный индекс для мгновенной постраничной выборки активных заказов конкретного клиента в личном кабинете без необходимости дополнительной сортировки.
16. **GIN-индекс поиска по номеру заказа (`pg_trgm`):**
    * `CREATE INDEX idx_orders_order_number_trgm ON orders USING gin (order_number gin_trgm_ops) WHERE is_deleted = false;`
    * *Обоснование:* Обеспечивает мгновенный регистронезависимый поиск заказа по неполному трек-номеру или его части (`ILIKE '%2026%'`) в диспетчерском журнале без полного сканирования таблицы (`Seq Scan`).
17. **`idx_shipments_status_active`**:
    * `CREATE INDEX idx_shipments_status_active ON shipments(status) WHERE is_deleted = false;`
    * *Обоснование:* Ускоряет диспетчерскую фильтрацию рейсов по статусам (`PLANNED`, `ON_ROUTE`, `COMPLETED`), исключая мягко удаленные записи из индекса и экономя оперативную память (RAM).
18. **`idx_shipments_driver_active_arrival`**:
    * `CREATE INDEX idx_shipments_driver_active_arrival ON shipments(driver_id, planned_arrival ASC) WHERE is_deleted = false;`
    * *Обоснование:* Составной частичный индекс для мгновенного получения активных путевых листов конкретного водителя с детерминированной сортировкой по дедлайну прибытия без задействования оперативной сортировки (`Sort Node`).
19. **GIN-индекс поиска по коду рейса (`pg_trgm`):**
    * `CREATE INDEX idx_shipments_code_trgm ON shipments USING gin (shipment_code gin_trgm_ops) WHERE is_deleted = false;`
    * *Обоснование:* Обеспечивает быстрый нечеткий регистронезависимый поиск рейса по номеру путевого листа или его части (`ILIKE '%...%'`) в строке поиска диспетчера без сканирования всей таблицы (`Seq Scan`).
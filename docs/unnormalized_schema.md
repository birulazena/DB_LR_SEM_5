# Ненормализованная инфологическая модель базы данных (Лабораторная работа №1)

## 1. Концепция ненормализованной модели

В рамках первого этапа проектирования предметная область логистических перевозок представлена в виде денормализованной схемы из 4 сводных таблиц.

---

## 2. Спецификация ненормализованных сущностей

### 1. `raw_users` (Учетные записи, профили и права)
Сводная таблица, объединяющая данные аутентификации, персональный профиль и матрицу доступа.
* `id` (UUID, PK) — первичный ключ.
* `email` (VARCHAR(150), NOT NULL) — адрес электронной почты (логин).
* `password_hash` (VARCHAR(255), NOT NULL) — хэш пароля.
* `first_name` (VARCHAR(100), NOT NULL) — имя пользователя.
* `last_name` (VARCHAR(100), NOT NULL) — фамилия пользователя.
* `phone` (VARCHAR(30), NOT NULL) — контактный номер телефона.
* `roles_and_permissions` (TEXT, NOT NULL) — перечисление ролей и прав через разделитель, например: "ROLE_DISPATCHER:orders:create,shipments:update" (нарушение 1НФ).
* `is_deleted` (BOOLEAN, NOT NULL, DEFAULT false) — флаг мягкого удаления.
> **Связи:** 1:M с `raw_orders` (по email клиента), 1:M с `raw_shipments` (по email водителя), 1:M с `raw_audit_logs` (по email автора).

### 2. `raw_orders` (Заказы, склады и грузы)
Сводная таблица, хранящая заказ, дублирующая данные клиентов, складов и перечень позиций груза.
* `id` (UUID, PK) — первичный ключ.
* `order_number` (VARCHAR(50), NOT NULL) — публичный трек-номер.
* `customer_email` (VARCHAR(150), NOT NULL) — email клиента.
* `customer_phone` (VARCHAR(30), NOT NULL) — телефон клиента (транзитивная зависимость от customer_email).
* `origin_warehouse_name` (VARCHAR(100), NOT NULL) — наименование склада отправления.
* `origin_warehouse_address` (VARCHAR(255), NOT NULL) — адрес склада отправления (транзитивная зависимость от origin_warehouse_name).
* `dest_warehouse_name` (VARCHAR(100), NOT NULL) — наименование склада назначения.
* `dest_warehouse_address` (VARCHAR(255), NOT NULL) — адрес склада назначения (транзитивная зависимость от dest_warehouse_name).
* `cargo_items_list` (TEXT, NOT NULL) — перечень мест груза строкой через разделитель: "Поддон:2:800kg|Коробка:10:50kg" (нарушение 1НФ).
* `total_cost` (NUMERIC(10, 2), NOT NULL, DEFAULT 0.00) — стоимость перевозки.
* `order_status` (VARCHAR(30), NOT NULL, DEFAULT 'CREATED') — статус заказа.
* `is_deleted` (BOOLEAN, NOT NULL, DEFAULT false) — флаг мягкого удаления.
> **Связи:** M:1 с таблицей `raw_users` (по customer_email).

### 3. `raw_shipments` (Рейсы, автомобили, водители и заказы)
Сводная таблица, объединяющая рейс, характеристики транспортного средства, водителя и состав отправлений.
* `id` (UUID, PK) — первичный ключ.
* `shipment_code` (VARCHAR(50), NOT NULL) — номер путевого листа.
* `vehicle_license_plate` (VARCHAR(20), NOT NULL) — госномер автомобиля.
* `vehicle_model` (VARCHAR(100), NOT NULL) — марка и модель машины (зависит от госномера, а не от ID рейса).
* `vehicle_max_weight_kg` (NUMERIC(10, 2), NOT NULL) — грузоподъемность авто (транзитивная зависимость от госномера).
* `driver_email` (VARCHAR(150), NOT NULL) — email назначенного водителя.
* `driver_phone` (VARCHAR(30), NOT NULL) — телефон водителя (дублирование данных).
* `orders_list` (TEXT, NOT NULL) — перечень трек-номеров включенных заказов через запятую: "ORD-001,ORD-002" (нарушение 1НФ, связь M:N через строку).
* `shipment_status` (VARCHAR(30), NOT NULL, DEFAULT 'PLANNED') — статус рейса.
* `planned_arrival` (TIMESTAMPTZ, NOT NULL) — плановое время завершения рейса.
* `is_deleted` (BOOLEAN, NOT NULL, DEFAULT false) — флаг мягкого удаления.
> **Связи:** M:1 с таблицей `raw_users` (по driver_email).

### 4. `raw_audit_logs` (Журнал аудита операций)
Таблица фиксации изменений с прямой строковой привязкой к почте пользователя.
* `id` (UUID, PK) — первичный ключ.
* `user_email` (VARCHAR(150), NOT NULL) — email пользователя, выполнившего действие.
* `action` (VARCHAR(50), NOT NULL) — тип выполненной операции.
* `entity_name` (VARCHAR(50), NOT NULL) — название измененной сущности.
* `entity_id` (UUID, NOT NULL) — идентификатор измененной записи.
* `details` (VARCHAR(255), NOT NULL) — краткое текстовое описание изменения.
* `created_at` (TIMESTAMPTZ, NOT NULL, DEFAULT CURRENT_TIMESTAMP) — время фиксации события.
> **Связи:** M:1 с таблицей `raw_users` (по user_email).

---

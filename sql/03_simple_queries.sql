-- ----------------------------------------------------------------------------
-- 1. АУТЕНТИФИКАЦИЯ И БЕЗОПАСНОСТЬ
-- ----------------------------------------------------------------------------

-- [1.1] Получение пользователя по email для аутентификации со всеми ролями и пермишенами
SELECT
    u.id,
    u.email,
    u.password_hash,
    u.is_active,
    u.is_deleted,
    COALESCE(ARRAY_AGG(DISTINCT r.name) FILTER (WHERE r.name IS NOT NULL), '{}') AS roles,
    COALESCE(ARRAY_AGG(DISTINCT p.code) FILTER (WHERE p.code IS NOT NULL), '{}') AS permissions
FROM users u
         LEFT JOIN user_roles ur ON u.id = ur.user_id
         LEFT JOIN roles r ON ur.role_id = r.id
         LEFT JOIN role_permissions rp ON r.id = rp.role_id
         LEFT JOIN permissions p ON rp.permission_id = p.id
WHERE u.email = :email
  AND u.is_deleted = false
GROUP BY u.id, u.email, u.password_hash, u.is_active, u.is_deleted;


-- [1.2] Быстрая проверка занятости логина или телефона перед регистрацией
SELECT
    EXISTS(SELECT 1 FROM users WHERE email = :email AND is_deleted = false) AS email_exists,
    EXISTS(SELECT 1 FROM user_profiles WHERE phone = :phone AND is_deleted = false) AS phone_exists;


-- ----------------------------------------------------------------------------
-- 2. РЕГИСТРАЦИЯ И СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ
-- ----------------------------------------------------------------------------

-- [2.1] Создание записи учетной записи
INSERT INTO users (id, email, password_hash, is_active, is_deleted, created_at)
VALUES (:id, :email, :passwordHash, :isActive, false, CURRENT_TIMESTAMP);


-- [2.2] Создание персонального профиля
INSERT INTO user_profiles (id, user_id, first_name, last_name, phone, is_deleted)
VALUES (:id, :userId, :firstName, :lastName, :phone, false);


-- [2.3] Назначение базовой роли пользователю
INSERT INTO user_roles (user_id, role_id)
VALUES (:userId, :roleId)
    ON CONFLICT DO NOTHING;

-- [2.3] Назначение роли по имени роли
INSERT INTO user_roles (user_id, role_id)
VALUES (:userId, (SELECT id FROM roles WHERE name = :roleName))
    ON CONFLICT DO NOTHING;


-- ----------------------------------------------------------------------------
-- 3. ПОЛУЧЕНИЕ И ФИЛЬТРАЦИЯ ДАННЫХ
-- ----------------------------------------------------------------------------

-- [3.1] Получение детальной карточки пользователя по ID
SELECT
    u.id,
    u.email,
    u.is_active,
    u.created_at,
    up.id AS profile_id,
    up.first_name,
    up.last_name,
    up.phone,
    COALESCE(ARRAY_AGG(DISTINCT r.name) FILTER (WHERE r.name IS NOT NULL), '{}') AS roles
FROM users u
         INNER JOIN user_profiles up ON u.id = up.user_id
         LEFT JOIN user_roles ur ON u.id = ur.user_id
         LEFT JOIN roles r ON ur.role_id = r.id
WHERE u.id = :userId
  AND u.is_deleted = false
  AND up.is_deleted = false
GROUP BY u.id, u.email, u.is_active, u.created_at, up.id, up.first_name, up.last_name, up.phone;


-- [3.2] Пагинированный список пользователей с фильтрацией
WITH target_users AS (
    SELECT u.id
    FROM users u
             INNER JOIN user_profiles up ON u.id = up.user_id
    WHERE u.is_deleted = false
      AND up.is_deleted = false
      AND (:isActive::BOOLEAN IS NULL OR u.is_active = :isActive)
      AND (:search::VARCHAR IS NULL OR (
            u.email ILIKE '%' || :search || '%' OR
            up.first_name ILIKE '%' || :search || '%' OR
            up.last_name ILIKE '%' || :search || '%' OR
            up.phone ILIKE '%' || :search || '%'
      ))
      AND (:roleName::VARCHAR IS NULL OR EXISTS (
            SELECT 1 FROM user_roles ur2
            JOIN roles r2 ON ur2.role_id = r2.id
            WHERE ur2.user_id = u.id AND r2.name = :roleName
      ))
    ORDER BY u.created_at DESC
    LIMIT :limit OFFSET :offset
    )
SELECT
    u.id,
    u.email,
    u.is_active,
    u.created_at,
    up.first_name,
    up.last_name,
    up.phone,
    COALESCE(ARRAY_AGG(DISTINCT r.name) FILTER (WHERE r.name IS NOT NULL), '{}') AS roles
FROM target_users tu
         JOIN users u ON tu.id = u.id
         JOIN user_profiles up ON u.id = up.user_id
         LEFT JOIN user_roles ur ON u.id = ur.user_id
         LEFT JOIN roles r ON ur.role_id = r.id
GROUP BY u.id, u.email, u.is_active, u.created_at, up.first_name, up.last_name, up.phone
ORDER BY u.created_at DESC;


-- [3.3] Подсчет общего количества записей под фильтры
SELECT COUNT(u.id) AS total_count
FROM users u
  INNER JOIN user_profiles up ON u.id = up.user_id
WHERE u.is_deleted = false
  AND up.is_deleted = false
  AND (:isActive::BOOLEAN IS NULL OR u.is_active = :isActive)
  AND (:search::VARCHAR IS NULL OR (
        u.email ILIKE '%' || :search || '%' OR
        up.first_name ILIKE '%' || :search || '%' OR
        up.last_name ILIKE '%' || :search || '%' OR
        up.phone ILIKE '%' || :search || '%'
  ))
  AND (:roleName::VARCHAR IS NULL OR EXISTS (
        SELECT 1 FROM user_roles ur2
        JOIN roles r2 ON ur2.role_id = r2.id
        WHERE ur2.user_id = u.id AND r2.name = :roleName
  ));


-- ----------------------------------------------------------------------------
-- 4. ОБНОВЛЕНИЕ ДАННЫХ (Update)
-- ----------------------------------------------------------------------------

-- [4.1] Обновление персональных данных профиля
UPDATE user_profiles
SET first_name = :firstName,
    last_name = :lastName,
    phone = :phone
WHERE user_id = :userId
    AND is_deleted = false;


-- [4.2] Смена пароля пользователя
UPDATE users
SET password_hash = :passwordHash
WHERE id = :userId
  AND is_deleted = false;


-- [4.3] Блокировка / разблокировка пользователя администратором
UPDATE users
SET is_active = :isActive
WHERE id = :userId
  AND is_deleted = false;


-- ----------------------------------------------------------------------------
-- 5. УПРАВЛЕНИЕ РОЛЯМИ (RBAC Management)
-- ----------------------------------------------------------------------------

-- [5.1] Отзыв роли у пользователя
DELETE FROM user_roles
WHERE user_id = :userId
  AND role_id = :roleId;


-- [5.2] Получение справочника всех ролей со всеми их разрешениями
SELECT
    r.id AS role_id,
    r.name AS role_name,
    r.description AS role_description,
    COALESCE(ARRAY_AGG(p.code) FILTER (WHERE p.code IS NOT NULL), '{}') AS permissions
FROM roles r
         LEFT JOIN role_permissions rp ON r.id = rp.role_id
         LEFT JOIN permissions p ON rp.permission_id = p.id
GROUP BY r.id, r.name, r.description
ORDER BY r.name ASC;


-- ----------------------------------------------------------------------------
-- 6. МЯГКОЕ УДАЛЕНИЕ И ВОССТАНОВЛЕНИЕ
-- ----------------------------------------------------------------------------

-- [6.1] МЯГКОЕ УДАЛЕНИЕ (В рамках транзакции)
UPDATE users
SET is_deleted = true,
    is_active = false
WHERE id = :userId
  AND is_deleted = false;

UPDATE user_profiles
SET is_deleted = true
WHERE user_id = :userId
  AND is_deleted = false;


-- [6.2] ВОССТАНОВЛЕНИЕ ПОЛЬЗОВАТЕЛЯ(В рамках транзакции)
UPDATE users
SET is_deleted = false,
    is_active = true
WHERE id = :userId
  AND is_deleted = true;

UPDATE user_profiles
SET is_deleted = false
WHERE user_id = :userId
  AND is_deleted = true;

-- ----------------------------------------------------------------------------
-- 7. СКЛАДЫ
-- ----------------------------------------------------------------------------

-- [7.1] ДАБВЛЕНИЕ НОВОГО СКЛАДА
INSERT INTO warehouses (id, name, address, is_deleted)
VALUES (:id, :name, :address, false);

-- [7.2] ПОЛУЧЕНИЕ СКЛАДА ПО ID
SELECT id, name, address, is_deleted
FROM warehouses
WHERE id = :id AND is_deleted = false;

-- [7.3] ПОИСК СКЛАДА ПО АДРЕСУ
SELECT id, name, address
FROM warehouses
WHERE address = :address AND is_deleted = false;

-- [7.4] ВЫБОР АКТИВНЫХ СКЛАДОВ ПО АЛФАВИТУ С ПАГИНАЦИЕЙ
SELECT id, name, address
FROM warehouses
WHERE is_deleted = false
ORDER BY name ASC, id ASC
    LIMIT :limit OFFSET :offset;

-- [7.5] ПОДСТЧЕТ ОБЩЕГО КОЛ-ВА СКЛАДОВ
SELECT count(*)
FROM warehouses
WHERE is_deleted = false;

-- [7.6] РЕДАКТИРОВАНИЕ НАЗВАНИЯ И АДРЕСА СКЛАДА
UPDATE warehouses
SET name = :name,
    address = :address
WHERE id = :id AND is_deleted = false;

-- [7.7] МЯГКОЕ УДАЛЕНИЕ СКЛАДА
UPDATE warehouses
SET is_deleted = true
WHERE id = :id AND is_deleted = false;

-- [7.8] ВОССТАНОВЛЕНИЕ СКЛАДА
UPDATE warehouses
SET is_deleted = false
WHERE id = :id AND is_deleted = true;

-- ----------------------------------------------------------------------------
-- 8. АВТОПАРК
-- ----------------------------------------------------------------------------

-- [8.1] ДОБАВЛЕНИЕ ТРАНСПОРТНОГО СРЕДСТВА
INSERT INTO vehicles (id, license_plate, model, max_weight_kg, current_warehouse_id, is_deleted)
VALUES (:id, :licensePlate, :model, :maxWeightKg, :currentWarehouseId, false);

-- [8.2] ПОИСК ТС ПО НОМЕРУ
SELECT id, license_plate, model, max_weight_kg, current_warehouse_id
FROM vehicles
WHERE license_plate = :licensePlate AND is_deleted = false;

-- [8.3] ПОЛУЧЕНИЕ ТС ПО ID
SELECT id, license_plate, model, max_weight_kg, current_warehouse_id
FROM vehicles
WHERE id = :id AND is_deleted = false;

-- [8.4] ВЫБОРКА ТС С ФИЛЬТРАМИ И ПАГИНАЦИЕЙ
SELECT id, license_plate, model, max_weight_kg, current_warehouse_id
FROM vehicles
WHERE is_deleted = false
  AND (:warehouseId::UUID IS NULL OR current_warehouse_id = :warehouseId)
  AND (:minWeight::NUMERIC IS NULL OR max_weight_kg >= :minWeight)
  AND (:modelQuery::VARCHAR IS NULL OR model ILIKE '%' || :modelQuery || '%')
ORDER BY model ASC, id ASC
    LIMIT :limit OFFSET :offset;

-- [8.5] ПОДСЧЕТ КОЛ-ВО АВТО ПО ФИЛЬТРАМ
SELECT count(*)
FROM vehicles
WHERE is_deleted = false
  AND (:warehouseId::UUID IS NULL OR current_warehouse_id = :warehouseId)
  AND (:minWeight::NUMERIC IS NULL OR max_weight_kg >= :minWeight)
  AND (:modelQuery::VARCHAR IS NULL OR model ILIKE '%' || :modelQuery || '%');

-- [8.6] ОБНОВЛЕНИЕ ПАРАМТЕРОВ АВТОМОБИЛЯ
UPDATE vehicles
SET license_plate = :licensePlate,
    model = :model,
    max_weight_kg = :maxWeightKg,
    current_warehouse_id = :currentWarehouseId
WHERE id = :id AND is_deleted = false;

-- [8.7] МЯГКОЕ УДАЛЕНИЕ
UPDATE vehicles
SET is_deleted = true
WHERE id = :id AND is_deleted = false;

-- [8.8] ВОССТАНОВЛЕНИЕ ТРАНСПОРТНОГО СРЕДСТВА
UPDATE vehicles
SET is_deleted = false
WHERE id = :id AND is_deleted = true;

-- ----------------------------------------------------------------------------
-- 9. ЖУРНАЛ АУДИТА (AUDIT LOGS)
-- ----------------------------------------------------------------------------

-- [9.1] Фиксация бизнес-события в журнале аудита
INSERT INTO audit_logs (id, user_id, action, entity_name, entity_id, details, created_at)
VALUES (:id, :userId, :action, :entityName, :entityId, :details, CURRENT_TIMESTAMP);


-- [9.2] Просмотр истории изменений конкретного объекта
SELECT
    al.id,
    al.user_id,
    u.email AS author_email,
    al.action,
    al.entity_name,
    al.entity_id,
    al.details,
    al.created_at
FROM audit_logs al
         JOIN users u ON al.user_id = u.id
WHERE al.entity_name = :entityName
  AND al.entity_id = :entityId
ORDER BY al.created_at DESC;


-- [9.3] Лента действий конкретного пользователя с пагинацией
SELECT id, user_id, action, entity_name, entity_id, details, created_at
FROM audit_logs
WHERE user_id = :userId
ORDER BY created_at DESC
    LIMIT :limit OFFSET :offset;


-- [9.4] Глобальная лента аудита системы с фильтрацией и пагинацией
SELECT
    al.id,
    al.user_id,
    u.email AS author_email,
    al.action,
    al.entity_name,
    al.entity_id,
    al.details,
    al.created_at
FROM audit_logs al
         JOIN users u ON al.user_id = u.id
WHERE (:userId::UUID IS NULL OR al.user_id = :userId)
  AND (:entityName::VARCHAR IS NULL OR al.entity_name = :entityName)
  AND (:action::VARCHAR IS NULL OR al.action = :action)
ORDER BY al.created_at DESC
    LIMIT :limit OFFSET :offset;


-- [9.5] Подсчет общего количества записей аудита под фильтры (для Page<AuditLog>)
SELECT count(al.id)
FROM audit_logs al
WHERE (:userId::UUID IS NULL OR al.user_id = :userId)
  AND (:entityName::VARCHAR IS NULL OR al.entity_name = :entityName)
  AND (:action::VARCHAR IS NULL OR al.action = :action);

-- ----------------------------------------------------------------------------
-- 10. ЗАКАЗЫ НА ГРУЗОПЕРЕВОЗКУ (ORDERS)
-- ----------------------------------------------------------------------------

-- [10.1] Оформление нового заказа
INSERT INTO orders (
    id,
    order_number,
    customer_id,
    origin_warehouse_id,
    destination_warehouse_id,
    total_cost,
    status,
    is_deleted,
    created_at
) VALUES (
             :id,
             :orderNumber,
             :customerId,
             :originWarehouseId,
             :destinationWarehouseId,
             :totalCost,
             :status,
             false,
             CURRENT_TIMESTAMP
         );

-- [10.2] Получение детальной карточки заказа по ID
SELECT
    o.id,
    o.order_number,
    o.total_cost,
    o.status,
    o.created_at,
    u.id AS customer_id,
    u.email AS customer_email,
    up.first_name AS customer_first_name,
    up.last_name AS customer_last_name,
    up.phone AS customer_phone,
    w_from.id AS origin_warehouse_id,
    w_from.name AS origin_warehouse_name,
    w_from.address AS origin_warehouse_address,
    w_to.id AS destination_warehouse_id,
    w_to.name AS destination_warehouse_name,
    w_to.address AS destination_warehouse_address
FROM orders o
         JOIN users u ON o.customer_id = u.id
         JOIN user_profiles up ON u.id = up.user_id
         JOIN warehouses w_from ON o.origin_warehouse_id = w_from.id
         JOIN warehouses w_to ON o.destination_warehouse_id = w_to.id
WHERE o.id = :orderId
  AND o.is_deleted = false;

-- [10.3] Поиск заказа по трек-номеру накладной (order_number)
SELECT
    o.id,
    o.order_number,
    o.total_cost,
    o.status,
    o.created_at,
    w_from.name AS origin_warehouse_name,
    w_to.name AS destination_warehouse_name
FROM orders o
         JOIN warehouses w_from ON o.origin_warehouse_id = w_from.id
         JOIN warehouses w_to ON o.destination_warehouse_id = w_to.id
WHERE o.order_number = :orderNumber
  AND o.is_deleted = false;

-- [10.4] Пагинированный список заказов конкретного клиента (Личный кабинет)
SELECT
    o.id,
    o.order_number,
    o.total_cost,
    o.status,
    o.created_at,
    w_from.name AS origin_warehouse_name,
    w_to.name AS destination_warehouse_name
FROM orders o
         JOIN warehouses w_from ON o.origin_warehouse_id = w_from.id
         JOIN warehouses w_to ON o.destination_warehouse_id = w_to.id
WHERE o.customer_id = :customerId
  AND o.is_deleted = false
ORDER BY o.created_at DESC
    LIMIT :limit OFFSET :offset;

-- [10.5] Подсчет количества заказов клиента под пагинацию
SELECT COUNT(id)
FROM orders
WHERE customer_id = :customerId
  AND is_deleted = false;

-- [10.6] Диспетчерский журнал заказов с гибкой фильтрацией и пагинацией
WITH target_orders AS (
    SELECT o.id
    FROM orders o
    WHERE o.is_deleted = false
      AND (:status::VARCHAR IS NULL OR o.status = :status)
      AND (:originWarehouseId::UUID IS NULL OR o.origin_warehouse_id = :originWarehouseId)
      AND (:destinationWarehouseId::UUID IS NULL OR o.destination_warehouse_id = :destinationWarehouseId)
      AND (:search::VARCHAR IS NULL OR o.order_number ILIKE '%' || :search || '%')
    ORDER BY o.created_at DESC
    LIMIT :limit OFFSET :offset
    )
SELECT
    o.id,
    o.order_number,
    o.total_cost,
    o.status,
    o.created_at,
    w_from.name AS origin_warehouse_name,
    w_to.name AS destination_warehouse_name,
    u.email AS customer_email,
    up.phone AS customer_phone
FROM target_orders to_orders
         JOIN orders o ON to_orders.id = o.id
         JOIN warehouses w_from ON o.origin_warehouse_id = w_from.id
         JOIN warehouses w_to ON o.destination_warehouse_id = w_to.id
         JOIN users u ON o.customer_id = u.id
         JOIN user_profiles up ON u.id = up.user_id
ORDER BY o.created_at DESC;

-- [10.7] Подсчет количества заказов для диспетчерского журнала
SELECT COUNT(o.id)
FROM orders o
WHERE o.is_deleted = false
  AND (:status::VARCHAR IS NULL OR o.status = :status)
  AND (:originWarehouseId::UUID IS NULL OR o.origin_warehouse_id = :originWarehouseId)
  AND (:destinationWarehouseId::UUID IS NULL OR o.destination_warehouse_id = :destinationWarehouseId)
  AND (:search::VARCHAR IS NULL OR o.order_number ILIKE '%' || :search || '%');

-- [10.8] Смена статуса заказа
UPDATE orders
SET status = :status
WHERE id = :orderId
  AND is_deleted = false;

-- [10.9] Корректировка расчетной стоимости заказа
UPDATE orders
SET total_cost = :totalCost
WHERE id = :orderId
  AND is_deleted = false;

-- [10.10] Мягкое удаление заказа (Soft Delete)
UPDATE orders
SET is_deleted = true
WHERE id = :orderId
  AND is_deleted = false;

-- [10.11] Восстановление удаленного заказа
UPDATE orders
SET is_deleted = false
WHERE id = :orderId
  AND is_deleted = true;

-- ----------------------------------------------------------------------------
-- 11. ГРУЗОВЫЕ МЕСТА ЗАКАЗА (CARGO ITEMS)
-- ----------------------------------------------------------------------------

-- [11.1] Добавление грузового места в заказ
INSERT INTO cargo_items (
    id,
    order_id,
    name,
    quantity,
    weight_kg,
    volume_m3
) VALUES (
             :id,
             :orderId,
             :name,
             :quantity,
             :weightKg,
             :volumeM3
         );

-- [11.2] Получение состава груза по ID заказа
SELECT
    id,
    order_id,
    name,
    quantity,
    weight_kg,
    volume_m3,
    (quantity * weight_kg) AS total_item_weight,
    (quantity * volume_m3) AS total_item_volume
FROM cargo_items
WHERE order_id = :orderId
ORDER BY name ASC, id ASC;

-- [11.3] Получение конкретной позиции груза по ID
SELECT
    id,
    order_id,
    name,
    quantity,
    weight_kg,
    volume_m3
FROM cargo_items
WHERE id = :itemId;

-- [11.4] Редактирование характеристик грузового места
UPDATE cargo_items
SET name = :name,
    quantity = :quantity,
    weight_kg = :weightKg,
    volume_m3 = :volumeM3
WHERE id = :itemId;

-- [11.5] Физическое удаление позиции груза из накладной
DELETE FROM cargo_items
WHERE id = :itemId;

-- [11.6] Расчет суммарного веса, объема и числа мест в заказе
SELECT
    COALESCE(SUM(quantity), 0) AS total_packages_count,
    COALESCE(SUM(quantity * weight_kg), 0.00) AS total_order_weight_kg,
    COALESCE(SUM(quantity * volume_m3), 0.000) AS total_order_volume_m3
FROM cargo_items
WHERE order_id = :orderId;

-- ----------------------------------------------------------------------------
-- 12. КОНСОЛИДИРОВАННЫЕ РЕЙСЫ (SHIPMENTS)
-- ----------------------------------------------------------------------------

-- [12.1] Создание нового рейса диспетчером
INSERT INTO shipments (
    id,
    shipment_code,
    vehicle_id,
    driver_id,
    status,
    planned_arrival,
    is_deleted
) VALUES (
             :id,
             :shipmentCode,
             :vehicleId,
             :driverId,
             :status,
             :plannedArrival,
             false
         );

-- [12.2] Получение детальной карточки рейса по ID
SELECT
    s.id,
    s.shipment_code,
    s.status,
    s.planned_arrival,
    v.id AS vehicle_id,
    v.license_plate,
    v.model,
    v.max_weight_kg,
    u.id AS driver_id,
    u.email AS driver_email,
    up.first_name AS driver_first_name,
    up.last_name AS driver_last_name,
    up.phone AS driver_phone
FROM shipments s
         JOIN vehicles v ON s.vehicle_id = v.id
         JOIN users u ON s.driver_id = u.id
         JOIN user_profiles up ON u.id = up.user_id
WHERE s.id = :shipmentId
  AND s.is_deleted = false;

-- [12.3] Поиск рейса по коду накладной (shipment_code)
SELECT
    s.id,
    s.shipment_code,
    s.status,
    s.planned_arrival,
    v.license_plate,
    v.model,
    up.first_name AS driver_first_name,
    up.last_name AS driver_last_name,
    up.phone AS driver_phone
FROM shipments s
         JOIN vehicles v ON s.vehicle_id = v.id
         JOIN user_profiles up ON s.driver_id = up.user_id
WHERE s.shipment_code = :shipmentCode
  AND s.is_deleted = false;

-- [12.4] Список рейсов конкретного водителя с пагинацией (Мобильное приложение водителя)
SELECT
    s.id,
    s.shipment_code,
    s.status,
    s.planned_arrival,
    v.license_plate,
    v.model,
    v.max_weight_kg
FROM shipments s
         JOIN vehicles v ON s.vehicle_id = v.id
WHERE s.driver_id = :driverId
  AND s.is_deleted = false
ORDER BY s.planned_arrival ASC, s.id ASC
    LIMIT :limit OFFSET :offset;

-- [12.5] Подсчет количества рейсов водителя под пагинацию
SELECT COUNT(id)
FROM shipments
WHERE driver_id = :driverId
  AND is_deleted = false;

-- [12.6] Диспетчерский монитор рейсов с фильтрацией и пагинацией
WITH target_shipments AS (
    SELECT s.id
    FROM shipments s
    WHERE s.is_deleted = false
      AND (:status::VARCHAR IS NULL OR s.status = :status)
      AND (:vehicleId::UUID IS NULL OR s.vehicle_id = :vehicleId)
      AND (:driverId::UUID IS NULL OR s.driver_id = :driverId)
      AND (:search::VARCHAR IS NULL OR s.shipment_code ILIKE '%' || :search || '%')
    ORDER BY s.planned_arrival ASC, s.id ASC
    LIMIT :limit OFFSET :offset
    )
SELECT
    s.id,
    s.shipment_code,
    s.status,
    s.planned_arrival,
    v.id AS vehicle_id,
    v.license_plate,
    v.model,
    u.email AS driver_email,
    up.first_name AS driver_first_name,
    up.last_name AS driver_last_name,
    up.phone AS driver_phone
FROM target_shipments ts
         JOIN shipments s ON ts.id = s.id
         JOIN vehicles v ON s.vehicle_id = v.id
         JOIN users u ON s.driver_id = u.id
         JOIN user_profiles up ON u.id = up.user_id
ORDER BY s.planned_arrival ASC, s.id ASC;

-- [12.7] Подсчет количества рейсов для диспетчерского монитора
SELECT COUNT(s.id)
FROM shipments s
WHERE s.is_deleted = false
  AND (:status::VARCHAR IS NULL OR s.status = :status)
  AND (:vehicleId::UUID IS NULL OR s.vehicle_id = :vehicleId)
  AND (:driverId::UUID IS NULL OR s.driver_id = :driverId)
  AND (:search::VARCHAR IS NULL OR s.shipment_code ILIKE '%' || :search || '%');

-- [12.8] Смена статуса рейса (водителем или диспетчером)
UPDATE shipments
SET status = :status
WHERE id = :shipmentId
  AND is_deleted = false;

-- [12.9] Корректировка планового времени прибытия
UPDATE shipments
SET planned_arrival = :plannedArrival
WHERE id = :shipmentId
  AND is_deleted = false;

-- [12.10] Мягкое удаление рейса (Soft Delete)
UPDATE shipments
SET is_deleted = true
WHERE id = :shipmentId
  AND is_deleted = false;

-- [12.11] Восстановление отмененного рейса
UPDATE shipments
SET is_deleted = false
WHERE id = :shipmentId
  AND is_deleted = true;

-- ----------------------------------------------------------------------------
-- 13. КОМПЛЕКТОВАНИЕ РЕЙСОВ ЗАКАЗАМИ (SHIPMENT ORDERS)
-- ----------------------------------------------------------------------------

-- [13.1] Включение заказа в рейс (Консолидация накладной)
INSERT INTO shipment_orders (
    id,
    shipment_id,
    order_id,
    is_delivered
) VALUES (
             :id,
             :shipmentId,
             :orderId,
             false
         )
    ON CONFLICT (shipment_id, order_id) DO NOTHING;

-- [13.2] Исключение заказа из рейса
DELETE FROM shipment_orders
WHERE shipment_id = :shipmentId
  AND order_id = :orderId;

-- [13.3] Получение списка заказов для конкретного рейса
SELECT
    so.id AS item_id,
    so.is_delivered,
    o.id AS order_id,
    o.order_number,
    o.total_cost,
    o.status AS order_status,
    w_dest.name AS destination_warehouse_name,
    w_dest.address AS destination_warehouse_address,
    up.first_name AS customer_first_name,
    up.last_name AS customer_last_name,
    up.phone AS customer_phone
FROM shipment_orders so
         JOIN orders o ON so.order_id = o.id
         JOIN warehouses w_dest ON o.destination_warehouse_id = w_dest.id
         JOIN users u ON o.customer_id = u.id
         JOIN user_profiles up ON u.id = up.user_id
WHERE so.shipment_id = :shipmentId
  AND o.is_deleted = false
ORDER BY so.is_delivered ASC, o.order_number ASC;

-- [13.4] Поиск назначенного рейса по ID заказа
SELECT
    s.id AS shipment_id,
    s.shipment_code,
    s.status AS shipment_status,
    s.planned_arrival,
    so.is_delivered
FROM shipment_orders so
         JOIN shipments s ON so.shipment_id = s.id
WHERE so.order_id = :orderId
  AND s.is_deleted = false;

-- [13.5] Фиксация доставки заказа водителем
UPDATE shipment_orders
SET is_delivered = true
WHERE shipment_id = :shipmentId
  AND order_id = :orderId;

-- [13.6] Проверка готовности рейса к закрытию
SELECT EXISTS (
    SELECT 1
    FROM shipment_orders
    WHERE shipment_id = :shipmentId
      AND is_delivered = false
) AS has_undelivered_orders;

-- [13.7] Сводка прогресса выполнения рейса
SELECT
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE is_delivered = true) AS delivered_orders,
    COUNT(*) FILTER (WHERE is_delivered = false) AS pending_orders
FROM shipment_orders
WHERE shipment_id = :shipmentId;

INSERT INTO users (
    email,
    password_hash,
    is_active
) VALUES
      ('admin@logitrack.com',          '$argon2id$v=19$m=16384,t=2,p=1$UE5raGN0VzFBc245SnVRbQ$ftpeEVhnUQyJOMYwJsbRhe/IdvTLABt8O5HmAuzMntM', true),
      ('dispatcher@logitrack.com',     '$argon2id$v=19$m=16384,t=2,p=1$UE5raGN0VzFBc245SnVRbQ$ftpeEVhnUQyJOMYwJsbRhe/IdvTLABt8O5HmAuzMntM',  true),
      ('driver.ivan@logitrack.com',    '$argon2id$v=19$m=16384,t=2,p=1$UE5raGN0VzFBc245SnVRbQ$ftpeEVhnUQyJOMYwJsbRhe/IdvTLABt8O5HmAuzMntM', true),
      ('driver.sergey@logitrack.com',  '$argon2id$v=19$m=16384,t=2,p=1$UE5raGN0VzFBc245SnVRbQ$ftpeEVhnUQyJOMYwJsbRhe/IdvTLABt8O5HmAuzMntM', true),
      ('client.morozov@company.by',    '$argon2id$v=19$m=16384,t=2,p=1$UE5raGN0VzFBc245SnVRbQ$ftpeEVhnUQyJOMYwJsbRhe/IdvTLABt8O5HmAuzMntM', true),
      ('client.novikova@trade.by',     '$argon2id$v=19$m=16384,t=2,p=1$UE5raGN0VzFBc245SnVRbQ$ftpeEVhnUQyJOMYwJsbRhe/IdvTLABt8O5HmAuzMntM', true);



INSERT INTO user_profiles (
    user_id,
    first_name,
    last_name,
    phone
) VALUES
      ((SELECT id FROM users WHERE email = 'admin@logitrack.com'),         'Алексей', 'Смирнов',  '+375291112233'),
      ((SELECT id FROM users WHERE email = 'dispatcher@logitrack.com'),    'Елена',   'Ковалева', '+375292223344'),
      ((SELECT id FROM users WHERE email = 'driver.ivan@logitrack.com'),   'Иван',    'Петров',   '+375293334455'),
      ((SELECT id FROM users WHERE email = 'driver.sergey@logitrack.com'), 'Сергей',  'Сидоров',  '+375294445566'),
      ((SELECT id FROM users WHERE email = 'client.morozov@company.by'),   'Дмитрий', 'Морозов',  '+375295556677'),
      ((SELECT id FROM users WHERE email = 'client.novikova@trade.by'),    'Ольга',   'Новикова', '+375296667788');


INSERT INTO roles (
    name,
    description
) VALUES
      ('ADMIN',      'Полный административный доступ к системе'),
      ('DISPATCHER', 'Управление складами, рейсами и распределением заказов'),
      ('DRIVER',     'Водитель транспортного средства, выполнение рейсов'),
      ('CLIENT',     'Клиент логистической компании, оформление заказов');


INSERT INTO permissions (
    code,
    description
) VALUES
      ('users:manage',      'Создание, блокировка и редактирование пользователей'),
      ('orders:create',     'Оформление новых заявок на перевозку'),
      ('orders:read',       'Просмотр информации о заказах'),
      ('orders:update',     'Изменение параметров заказа и смена статусов'),
      ('shipments:manage',  'Формирование и планирование рейсов'),
      ('shipments:execute', 'Изменение статуса доставки рейса водителем');


INSERT INTO user_roles (
    user_id,
    role_id
) VALUES
      ((SELECT id FROM users WHERE email = 'admin@logitrack.com'),         (SELECT id FROM roles WHERE name = 'ADMIN')),
      ((SELECT id FROM users WHERE email = 'dispatcher@logitrack.com'),    (SELECT id FROM roles WHERE name = 'DISPATCHER')),
      ((SELECT id FROM users WHERE email = 'driver.ivan@logitrack.com'),   (SELECT id FROM roles WHERE name = 'DRIVER')),
      ((SELECT id FROM users WHERE email = 'driver.sergey@logitrack.com'), (SELECT id FROM roles WHERE name = 'DRIVER')),
      ((SELECT id FROM users WHERE email = 'client.morozov@company.by'),   (SELECT id FROM roles WHERE name = 'CLIENT')),
      ((SELECT id FROM users WHERE email = 'client.novikova@trade.by'),    (SELECT id FROM roles WHERE name = 'CLIENT'));


INSERT INTO role_permissions (
    role_id,
    permission_id
)
SELECT
    r.id,
    p.id
FROM roles r, permissions p
WHERE r.name = 'ADMIN';


INSERT INTO role_permissions (
    role_id,
    permission_id
) VALUES
      ((SELECT id FROM roles WHERE name = 'DISPATCHER'), (SELECT id FROM permissions WHERE code = 'orders:read')),
      ((SELECT id FROM roles WHERE name = 'DISPATCHER'), (SELECT id FROM permissions WHERE code = 'orders:update')),
      ((SELECT id FROM roles WHERE name = 'DISPATCHER'), (SELECT id FROM permissions WHERE code = 'shipments:manage'));


INSERT INTO role_permissions (
    role_id,
    permission_id
) VALUES
      ((SELECT id FROM roles WHERE name = 'DRIVER'), (SELECT id FROM permissions WHERE code = 'orders:read')),
      ((SELECT id FROM roles WHERE name = 'DRIVER'), (SELECT id FROM permissions WHERE code = 'shipments:execute'));


INSERT INTO role_permissions (
    role_id,
    permission_id
) VALUES
      ((SELECT id FROM roles WHERE name = 'CLIENT'), (SELECT id FROM permissions WHERE code = 'orders:create')),
      ((SELECT id FROM roles WHERE name = 'CLIENT'), (SELECT id FROM permissions WHERE code = 'orders:read'));


INSERT INTO warehouses (
    name,
    address
) VALUES
      ('Хаб Минск-Север',     'г. Минск, Долгиновский тракт, 180'),
      ('Терминал Брест-Запад', 'г. Брест, ул. Коммерческая, 17'),
      ('Склад Гродно-Восток',  'г. Гродно, ул. Карского, 4');


INSERT INTO vehicles (
    license_plate,
    model,
    max_weight_kg,
    current_warehouse_id
) VALUES
      ('1234 AA-7', 'Mercedes-Benz Actros 1845', 20000.00, (SELECT id FROM warehouses WHERE name = 'Хаб Минск-Север')),
      ('5678 BB-1', 'Scania R450',               22000.00, (SELECT id FROM warehouses WHERE name = 'Терминал Брест-Запад')),
      ('9012 CC-4', 'MAN TGX 18.500',            18000.00, (SELECT id FROM warehouses WHERE name = 'Склад Гродно-Восток'));


INSERT INTO orders (
    order_number,
    customer_id,
    origin_warehouse_id,
    destination_warehouse_id,
    total_cost,
    status
) VALUES
      (
          'ORD-2026-001',
          (SELECT id FROM users WHERE email = 'client.morozov@company.by'),
          (SELECT id FROM warehouses WHERE name = 'Хаб Минск-Север'),
          (SELECT id FROM warehouses WHERE name = 'Терминал Брест-Запад'),
          1450.00,
          'CREATED'
      ),
      (
          'ORD-2026-002',
          (SELECT id FROM users WHERE email = 'client.morozov@company.by'),
          (SELECT id FROM warehouses WHERE name = 'Хаб Минск-Север'),
          (SELECT id FROM warehouses WHERE name = 'Склад Гродно-Восток'),
          980.50,
          'IN_TRANSIT'
      ),
      (
          'ORD-2026-003',
          (SELECT id FROM users WHERE email = 'client.novikova@trade.by'),
          (SELECT id FROM warehouses WHERE name = 'Терминал Брест-Запад'),
          (SELECT id FROM warehouses WHERE name = 'Хаб Минск-Север'),
          2100.00,
          'DELIVERED'
      );


INSERT INTO cargo_items (
    order_id,
    name,
    quantity,
    weight_kg,
    volume_m3
) VALUES
      ((SELECT id FROM orders WHERE order_number = 'ORD-2026-001'), 'Паллета со строительными смесями',   4,   800.00, 1.200),
      ((SELECT id FROM orders WHERE order_number = 'ORD-2026-001'), 'Утеплитель минераловатный',           10,   45.00, 2.500),
      ((SELECT id FROM orders WHERE order_number = 'ORD-2026-002'), 'Электроинструмент (ящики)',           15,   30.50, 0.400),
      ((SELECT id FROM orders WHERE order_number = 'ORD-2026-003'), 'Промышленное холодильное оборудов.',   1, 2400.00, 8.600);


INSERT INTO shipments (
    shipment_code,
    vehicle_id,
    driver_id,
    status,
    planned_arrival
) VALUES
      (
          'SHP-MSQ-BR-01',
          (SELECT id FROM vehicles WHERE license_plate = '1234 AA-7'),
          (SELECT id FROM users WHERE email = 'driver.ivan@logitrack.com'),
          'ON_ROUTE',
          CURRENT_TIMESTAMP + INTERVAL '2 days'
      ),
      (
          'SHP-BR-MSQ-02',
          (SELECT id FROM vehicles WHERE license_plate = '5678 BB-1'),
          (SELECT id FROM users WHERE email = 'driver.sergey@logitrack.com'),
          'COMPLETED',
          CURRENT_TIMESTAMP - INTERVAL '1 day'
      );


INSERT INTO shipment_orders (
    shipment_id,
    order_id,
    is_delivered
) VALUES
      (
          (SELECT id FROM shipments WHERE shipment_code = 'SHP-MSQ-BR-01'),
          (SELECT id FROM orders WHERE order_number = 'ORD-2026-001'),
          false
      ),
      (
          (SELECT id FROM shipments WHERE shipment_code = 'SHP-BR-MSQ-02'),
          (SELECT id FROM orders WHERE order_number = 'ORD-2026-003'),
          true
      );


INSERT INTO audit_logs (
    user_id,
    action,
    entity_name,
    entity_id,
    details
) VALUES
      (
          (SELECT id FROM users WHERE email = 'client.morozov@company.by'),
          'ORDER_CREATE',
          'orders',
          (SELECT id FROM orders WHERE order_number = 'ORD-2026-001'),
          'Создан новый заказ ORD-2026-001'
      ),
      (
          (SELECT id FROM users WHERE email = 'dispatcher@logitrack.com'),
          'STATUS_UPDATE',
          'orders',
          (SELECT id FROM orders WHERE order_number = 'ORD-2026-002'),
          'Статус заказа изменен на IN_TRANSIT'
      ),
      (
          (SELECT id FROM users WHERE email = 'driver.sergey@logitrack.com'),
          'DELIVERY_CONFIRM',
          'orders',
          (SELECT id FROM orders WHERE order_number = 'ORD-2026-003'),
          'Груз выдан получателю на складе Минск-Север'
      );
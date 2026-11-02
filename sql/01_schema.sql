CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE users (
                       id UUID PRIMARY KEY DEFAULT uuidv7(),
                       email VARCHAR(150) NOT NULL,
                       password_hash VARCHAR(255) NOT NULL,
                       is_active BOOLEAN NOT NULL DEFAULT true,
                       is_deleted BOOLEAN NOT NULL DEFAULT false,
                       created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_profiles (
                               id UUID PRIMARY KEY DEFAULT uuidv7(),
                               user_id UUID NOT NULL UNIQUE,
                               first_name VARCHAR(100) NOT NULL,
                               last_name VARCHAR(100) NOT NULL,
                               phone VARCHAR(30) NOT NULL,
                               is_deleted BOOLEAN NOT NULL DEFAULT false,
                               CONSTRAINT fk_user_profiles_user
                                   FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE roles (
                       id UUID PRIMARY KEY DEFAULT uuidv7(),
                       name VARCHAR(50) NOT NULL UNIQUE,
                       description VARCHAR(255)
);

CREATE TABLE permissions (
                             id UUID PRIMARY KEY DEFAULT uuidv7(),
                             code VARCHAR(100) NOT NULL UNIQUE,
                             description VARCHAR(255)
);

CREATE TABLE user_roles (
                            user_id UUID NOT NULL,
                            role_id UUID NOT NULL,
                            PRIMARY KEY (user_id, role_id),
                            CONSTRAINT fk_user_roles_user
                                FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
                            CONSTRAINT fk_user_roles_role
                                FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE CASCADE
);

CREATE TABLE role_permissions (
                                  role_id UUID NOT NULL,
                                  permission_id UUID NOT NULL,
                                  PRIMARY KEY (role_id, permission_id),
                                  CONSTRAINT fk_role_permissions_role
                                      FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE CASCADE,
                                  CONSTRAINT fk_role_permissions_permission
                                      FOREIGN KEY (permission_id) REFERENCES permissions (id) ON DELETE CASCADE
);

CREATE TABLE warehouses (
                            id UUID PRIMARY KEY DEFAULT uuidv7(),
                            name VARCHAR(100) NOT NULL,
                            address VARCHAR(255) NOT NULL,
                            is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE vehicles (
                          id UUID PRIMARY KEY DEFAULT uuidv7(),
                          license_plate VARCHAR(20) NOT NULL,
                          model VARCHAR(100) NOT NULL,
                          max_weight_kg NUMERIC(10, 2) NOT NULL,
                          current_warehouse_id UUID,
                          is_deleted BOOLEAN NOT NULL DEFAULT false,
                          CONSTRAINT chk_vehicles_max_weight
                              CHECK (max_weight_kg > 0),
                          CONSTRAINT fk_vehicles_current_warehouse
                              FOREIGN KEY (current_warehouse_id) REFERENCES warehouses (id) ON DELETE SET NULL
);

CREATE TABLE orders (
                        id UUID PRIMARY KEY DEFAULT uuidv7(),
                        order_number VARCHAR(50) NOT NULL UNIQUE,
                        customer_id UUID NOT NULL,
                        origin_warehouse_id UUID NOT NULL,
                        destination_warehouse_id UUID NOT NULL,
                        total_cost NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
                        status VARCHAR(30) NOT NULL,
                        is_deleted BOOLEAN NOT NULL DEFAULT false,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        CONSTRAINT chk_orders_cost_positive
                            CHECK (total_cost >= 0),
                        CONSTRAINT chk_orders_different_warehouses
                            CHECK (origin_warehouse_id <> destination_warehouse_id),
                        CONSTRAINT fk_orders_customer
                            FOREIGN KEY (customer_id) REFERENCES users (id) ON DELETE RESTRICT,
                        CONSTRAINT fk_orders_origin_warehouse
                            FOREIGN KEY (origin_warehouse_id) REFERENCES warehouses (id) ON DELETE RESTRICT,
                        CONSTRAINT fk_orders_destination_warehouse
                            FOREIGN KEY (destination_warehouse_id) REFERENCES warehouses (id) ON DELETE RESTRICT
);

CREATE TABLE cargo_items (
                             id UUID PRIMARY KEY DEFAULT uuidv7(),
                             order_id UUID NOT NULL,
                             name VARCHAR(150) NOT NULL,
                             quantity INT NOT NULL DEFAULT 1,
                             weight_kg NUMERIC(10, 2) NOT NULL,
                             volume_m3 NUMERIC(10, 3) NOT NULL,
                             CONSTRAINT chk_cargo_items_quantity
                                 CHECK (quantity > 0),
                             CONSTRAINT chk_cargo_items_weight
                                 CHECK (weight_kg > 0),
                             CONSTRAINT chk_cargo_items_volume
                                 CHECK (volume_m3 > 0),
                             CONSTRAINT fk_cargo_items_order
                                 FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
);

CREATE TABLE shipments (
                           id UUID PRIMARY KEY DEFAULT uuidv7(),
                           shipment_code VARCHAR(50) NOT NULL UNIQUE,
                           vehicle_id UUID NOT NULL,
                           driver_id UUID NOT NULL,
                           status VARCHAR(30) NOT NULL,
                           planned_arrival TIMESTAMPTZ NOT NULL,
                           is_deleted BOOLEAN NOT NULL DEFAULT false,
                           CONSTRAINT fk_shipments_vehicle
                               FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE RESTRICT,
                           CONSTRAINT fk_shipments_driver
                               FOREIGN KEY (driver_id) REFERENCES users (id) ON DELETE RESTRICT
);

CREATE TABLE shipment_orders (
                                 id UUID PRIMARY KEY DEFAULT uuidv7(),
                                 shipment_id UUID NOT NULL,
                                 order_id UUID NOT NULL,
                                 is_delivered BOOLEAN NOT NULL DEFAULT false,
                                 CONSTRAINT uq_shipment_orders_pair
                                     UNIQUE (shipment_id, order_id),
                                 CONSTRAINT fk_shipment_orders_shipment
                                     FOREIGN KEY (shipment_id) REFERENCES shipments (id) ON DELETE CASCADE,
                                 CONSTRAINT fk_shipment_orders_order
                                     FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
);

CREATE TABLE audit_logs (
                            id UUID PRIMARY KEY DEFAULT uuidv7(),
                            user_id UUID NOT NULL,
                            action VARCHAR(50) NOT NULL,
                            entity_name VARCHAR(50) NOT NULL,
                            entity_id UUID NOT NULL,
                            details VARCHAR(255) NOT NULL,
                            created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
                            CONSTRAINT fk_audit_logs_user
                                FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_origin_warehouse_id ON orders (origin_warehouse_id);
CREATE INDEX IF NOT EXISTS idx_orders_destination_warehouse_id ON orders (destination_warehouse_id);
CREATE INDEX IF NOT EXISTS idx_cargo_items_order_id ON cargo_items (order_id);
CREATE INDEX IF NOT EXISTS idx_shipments_vehicle_id ON shipments (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_shipments_driver_id ON shipments (driver_id);
CREATE INDEX IF NOT EXISTS idx_shipment_orders_order_id ON shipment_orders (order_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_orders_status_active ON orders (status) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs (entity_name, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_created_at_desc ON users(created_at DESC) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_warehouses_active_name_id ON warehouses (name ASC, id ASC) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_vehicles_active_model_id ON vehicles (model ASC, id ASC) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_vehicles_active_filters ON vehicles (current_warehouse_id, max_weight_kg) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_orders_created_at_desc ON orders (created_at DESC) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_orders_customer_active_created ON orders (customer_id, created_at DESC) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_shipments_status_active ON shipments (status) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_shipments_driver_active_arrival ON shipments (driver_id, planned_arrival ASC) WHERE is_deleted = false;


CREATE UNIQUE INDEX IF NOT EXISTS idx_users_unique_active_email ON users(email) WHERE is_deleted = false;
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_unique_active_phone ON user_profiles(phone) WHERE is_deleted = false;
CREATE UNIQUE INDEX IF NOT EXISTS idx_warehouses_unique_active_address ON warehouses (address) WHERE is_deleted = false;
CREATE UNIQUE INDEX IF NOT EXISTS idx_vehicles_unique_active_plate ON vehicles (license_plate) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_users_email_trgm ON users USING gin (email gin_trgm_ops) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_profiles_names_trgm ON user_profiles USING gin (first_name gin_trgm_ops, last_name gin_trgm_ops) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_profiles_phone_trgm ON user_profiles USING gin (phone gin_trgm_ops) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_vehicles_model_trgm ON vehicles USING gin (model gin_trgm_ops) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_orders_order_number_trgm ON orders USING gin (order_number gin_trgm_ops) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_shipments_code_trgm ON shipments USING gin (shipment_code gin_trgm_ops) WHERE is_deleted = false;
-- =========================================================
-- 1) Seguridad y cuentas
-- =========================================================
CREATE TABLE CUENTA (
  id_cuenta        BIGINT PRIMARY KEY,
  email            VARCHAR(255) NOT NULL UNIQUE,
  hash_password    VARBINARY(255) NOT NULL,
  rol              ENUM('cliente','tienda','repartidor','admin') NOT NULL,
  estado           ENUM('activo','suspendido','eliminado') NOT NULL DEFAULT 'activo',
  verificado       BOOLEAN NOT NULL DEFAULT FALSE,
  creado_en        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Perfiles por rol (vinculados a CUENTA)
CREATE TABLE PERFIL_CLIENTE (
  id_cuenta        BIGINT PRIMARY KEY,
  nombre           VARCHAR(120),
  apellido         VARCHAR(120),
  genero           ENUM('femenino','masculino','otro'),
  fecha_nacimiento DATE,
  telefono         VARCHAR(30),
  FOREIGN KEY (id_cuenta) REFERENCES CUENTA(id_cuenta)
);

CREATE TABLE PERFIL_REPARTIDOR (
  id_cuenta            BIGINT PRIMARY KEY,
  nombre               VARCHAR(120),
  apellido             VARCHAR(120),
  dpi                  VARCHAR(20),
  fecha_nacimiento     DATE,
  direccion            VARCHAR(160),
  telefono             VARCHAR(30),
  tipo_vehiculo        ENUM('moto','carro','bicicleta'),
  licencia             VARCHAR(30),
  num_placa            VARCHAR(30),
  num_cuenta_bancaria  VARCHAR(40),
  foto_url             VARCHAR(500),
  estado_operativo     ENUM('disponible','en_ruta','suspendido') DEFAULT 'disponible',
  FOREIGN KEY (id_cuenta) REFERENCES CUENTA(id_cuenta)
);

CREATE TABLE CATEGORIA_TIENDA (
  id_categoria  BIGINT PRIMARY KEY,
  nombre        VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE PERFIL_TIENDA (
  id_cuenta            BIGINT PRIMARY KEY,
  nombre_tienda        VARCHAR(150) NOT NULL,
  nombre_representante VARCHAR(120),
  documento_id         VARCHAR(40),
  telefono_contacto    VARCHAR(30),
  direccion            VARCHAR(160),
  id_categoria         BIGINT,
  logo_url             VARCHAR(500),
  num_cuenta_bancaria  VARCHAR(40),
  horario_apertura     TIME,
  horario_cierre       TIME,
  estado_tienda        ENUM('pendiente','activa','suspendida','rechazada') DEFAULT 'pendiente',
  FOREIGN KEY (id_cuenta)   REFERENCES CUENTA(id_cuenta),
  FOREIGN KEY (id_categoria) REFERENCES CATEGORIA_TIENDA(id_categoria)
);

CREATE TABLE PERFIL_ADMIN (
  id_cuenta  BIGINT PRIMARY KEY,
  nombre     VARCHAR(120),
  apellido   VARCHAR(120),
  nivel_permiso SMALLINT DEFAULT 1,
  FOREIGN KEY (id_cuenta) REFERENCES CUENTA(id_cuenta)
);

-- (Opcional) permisos granulares si los necesitas después
CREATE TABLE PERMISO (
  id_permiso BIGINT PRIMARY KEY,
  nombre     VARCHAR(80) NOT NULL UNIQUE
);

-- =========================================================
-- 2) Catálogo: categorías de producto, productos e inventario
-- =========================================================
CREATE TABLE CATEGORIA_PRODUCTO (
  id_categoria BIGINT PRIMARY KEY,
  nombre       VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE PRODUCTO (
  id_producto      BIGINT PRIMARY KEY,
  id_cuenta_tienda BIGINT NOT NULL,                 -- FK a PERFIL_TIENDA.id_cuenta
  nombre           VARCHAR(150) NOT NULL,
  descripcion      TEXT,
  precio           DECIMAL(10,2) NOT NULL,
  peso_kg          DECIMAL(10,3) NOT NULL,         -- requerido para costo de envío
  id_categoria     BIGINT,
  activo           BOOLEAN NOT NULL DEFAULT TRUE,
  creado_en        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (id_cuenta_tienda) REFERENCES PERFIL_TIENDA(id_cuenta),
  FOREIGN KEY (id_categoria)     REFERENCES CATEGORIA_PRODUCTO(id_categoria),
  INDEX idx_prod_tienda_activo (id_cuenta_tienda, activo)
);

CREATE TABLE PRODUCTO_IMAGEN (
  id_imagen    BIGINT PRIMARY KEY,
  id_producto  BIGINT NOT NULL,
  url          VARCHAR(500) NOT NULL,
  orden        INT DEFAULT 1,
  FOREIGN KEY (id_producto) REFERENCES PRODUCTO(id_producto)
);

CREATE TABLE INVENTARIO (
  id_producto  BIGINT PRIMARY KEY,
  stock        INT NOT NULL,
  umbral_bajo  INT NOT NULL DEFAULT 5,             -- para alerta de stock bajo
  FOREIGN KEY (id_producto) REFERENCES PRODUCTO(id_producto)
);

-- Etiquetas/promos a nivel producto o tienda (oferta, nuevo, descuento)
CREATE TABLE PROMOCION (
  id_promocion     BIGINT PRIMARY KEY,
  id_producto      BIGINT,
  id_cuenta_tienda BIGINT,
  etiqueta         ENUM('oferta','nuevo','descuento') NOT NULL,
  descuento_pct    DECIMAL(5,2),                    -- si aplica
  vigente_desde    DATE,
  vigente_hasta    DATE,
  activo           BOOLEAN DEFAULT TRUE,
  CHECK ((id_producto IS NOT NULL) OR (id_cuenta_tienda IS NOT NULL)),
  FOREIGN KEY (id_producto)      REFERENCES PRODUCTO(id_producto),
  FOREIGN KEY (id_cuenta_tienda) REFERENCES PERFIL_TIENDA(id_cuenta)
);

-- =========================================================
-- 3) Direcciones del cliente, carrito y pedido
-- =========================================================
CREATE TABLE DIRECCION_CLIENTE (
  id_direccion BIGINT PRIMARY KEY,
  id_cuenta    BIGINT NOT NULL,
  etiqueta     VARCHAR(40),        -- p. ej., Casa, Trabajo
  linea1       VARCHAR(160) NOT NULL,
  linea2       VARCHAR(160),
  ciudad       VARCHAR(80),
  departamento VARCHAR(80),
  referencia   VARCHAR(200),
  lat          DECIMAL(10,7),
  lng          DECIMAL(10,7),
  FOREIGN KEY (id_cuenta) REFERENCES CUENTA(id_cuenta),
  INDEX idx_dir_cuenta (id_cuenta)
);

-- Un carrito por cliente por tienda
CREATE TABLE CARRITO (
  id_carrito         BIGINT PRIMARY KEY,
  id_cuenta_cliente  BIGINT NOT NULL,              -- PERFIL_CLIENTE.id_cuenta
  id_cuenta_tienda   BIGINT NOT NULL,              -- PERFIL_TIENDA.id_cuenta
  creado_en          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE (id_cuenta_cliente, id_cuenta_tienda),
  FOREIGN KEY (id_cuenta_cliente) REFERENCES PERFIL_CLIENTE(id_cuenta),
  FOREIGN KEY (id_cuenta_tienda)  REFERENCES PERFIL_TIENDA(id_cuenta)
);

CREATE TABLE CARRITO_ITEM (
  id_carrito  BIGINT NOT NULL,
  id_producto BIGINT NOT NULL,
  cantidad    INT NOT NULL CHECK (cantidad > 0),
  PRIMARY KEY (id_carrito, id_producto),
  FOREIGN KEY (id_carrito) REFERENCES CARRITO(id_carrito),
  FOREIGN KEY (id_producto) REFERENCES PRODUCTO(id_producto)
);

-- Estados de pedido: pendiente → en_preparacion → listo → en_camino → entregado
CREATE TABLE PEDIDO (
  id_pedido         BIGINT PRIMARY KEY,
  id_cuenta_cliente BIGINT NOT NULL,
  id_cuenta_tienda  BIGINT NOT NULL,
  id_direccion      BIGINT NOT NULL,
  estado            ENUM('pendiente','en_preparacion','listo','en_camino','entregado','rechazado','cancelado') NOT NULL DEFAULT 'pendiente',
  subtotal          DECIMAL(12,2) NOT NULL,
  costo_envio       DECIMAL(12,2) NOT NULL,
  total             DECIMAL(12,2) NOT NULL,
  peso_total_kg     DECIMAL(10,3) NOT NULL,
  creado_en         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (id_cuenta_cliente) REFERENCES PERFIL_CLIENTE(id_cuenta),
  FOREIGN KEY (id_cuenta_tienda)  REFERENCES PERFIL_TIENDA(id_cuenta),
  FOREIGN KEY (id_direccion)      REFERENCES DIRECCION_CLIENTE(id_direccion),
  INDEX idx_pedido_cliente_fecha (id_cuenta_cliente, creado_en),
  INDEX idx_pedido_tienda_estado (id_cuenta_tienda, estado)
);

-- Snapshot de líneas (precio y peso al momento de la compra)
CREATE TABLE PEDIDO_ITEM (
  id_pedido                 BIGINT NOT NULL,
  id_producto               BIGINT NOT NULL,
  nombre_producto_snapshot  VARCHAR(150) NOT NULL,
  precio_unitario_snapshot  DECIMAL(10,2) NOT NULL,
  peso_kg_snapshot          DECIMAL(10,3) NOT NULL,
  cantidad                  INT NOT NULL,
  PRIMARY KEY (id_pedido, id_producto),
  FOREIGN KEY (id_pedido)   REFERENCES PEDIDO(id_pedido),
  FOREIGN KEY (id_producto) REFERENCES PRODUCTO(id_producto)
);

CREATE TABLE HISTORIAL_ESTADO_PEDIDO (
  id_historial BIGINT PRIMARY KEY,
  id_pedido    BIGINT NOT NULL,
  estado       ENUM('pendiente','en_preparacion','listo','en_camino','entregado','rechazado','cancelado') NOT NULL,
  motivo       VARCHAR(200),
  cambiado_por BIGINT,  -- CUENTA del actor (admin/tienda/repartidor/sistema)
  cambiado_en  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (id_pedido) REFERENCES PEDIDO(id_pedido),
  INDEX idx_hist_pedido (id_pedido, cambiado_en)
);

-- =========================================================
-- 4) Pagos y notificaciones
-- =========================================================
CREATE TABLE METODO_PAGO (
  id_metodo SMALLINT PRIMARY KEY,
  nombre    VARCHAR(40) NOT NULL UNIQUE     -- tarjeta, transferencia, contra_entrega, etc.
);

CREATE TABLE PAGO (
  id_pago    BIGINT PRIMARY KEY,
  id_pedido  BIGINT NOT NULL,
  id_metodo  SMALLINT NOT NULL,
  monto      DECIMAL(12,2) NOT NULL,
  estado     ENUM('pendiente','aprobado','rechazado','reembolsado') NOT NULL DEFAULT 'pendiente',
  referencia VARCHAR(160),
  pagado_en  TIMESTAMP NULL,
  FOREIGN KEY (id_pedido) REFERENCES PEDIDO(id_pedido),
  FOREIGN KEY (id_metodo) REFERENCES METODO_PAGO(id_metodo),
  INDEX idx_pago_pedido (id_pedido)
);

CREATE TABLE NOTIFICACION (
  id_notificacion BIGINT PRIMARY KEY,
  id_cuenta       BIGINT NOT NULL,
  canal           ENUM('correo','push') NOT NULL,
  asunto          VARCHAR(160),
  cuerpo          TEXT,
  enviado         BOOLEAN DEFAULT FALSE,
  creado_en       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  enviado_en      TIMESTAMP NULL,
  FOREIGN KEY (id_cuenta) REFERENCES CUENTA(id_cuenta),
  INDEX idx_notif_cuenta (id_cuenta, enviado)
);

-- =========================================================
-- 5) Repartidores: asignación y seguimiento
-- =========================================================
-- Flujo: asignado → aceptado → recogido → en_camino → entregado (o rechazado/fallido)
CREATE TABLE ASIGNACION_REPARTIDOR (
  id_asignacion   BIGINT PRIMARY KEY,
  id_pedido       BIGINT NOT NULL,
  id_cuenta_rep   BIGINT NOT NULL,           -- PERFIL_REPARTIDOR.id_cuenta
  estado          ENUM('asignado','aceptado','rechazado','recogido','en_camino','entregado','fallido') NOT NULL DEFAULT 'asignado',
  distancia_km    DECIMAL(10,2),
  costo_envio_visto DECIMAL(12,2),           -- costo visto al aceptar/rechazar
  creado_en       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (id_pedido)     REFERENCES PEDIDO(id_pedido),
  FOREIGN KEY (id_cuenta_rep) REFERENCES PERFIL_REPARTIDOR(id_cuenta),
  INDEX idx_asig_rep_estado (id_cuenta_rep, estado)
);

CREATE TABLE HISTORIAL_ENTREGA_REPARTIDOR (
  id_historial  BIGINT PRIMARY KEY,
  id_asignacion BIGINT NOT NULL,
  evento        ENUM('aceptado','rechazado','recogido','en_camino','entregado','fallido') NOT NULL,
  lat           DECIMAL(10,7),
  lng           DECIMAL(10,7),
  creado_en     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (id_asignacion) REFERENCES ASIGNACION_REPARTIDOR(id_asignacion),
  INDEX idx_hist_asig (id_asignacion, creado_en)
);

-- =========================================================
-- 6) Aprobaciones, auditoría y alertas de inventario
-- =========================================================
CREATE TABLE SOLICITUD_TIENDA (
  id_solicitud     BIGINT PRIMARY KEY,
  id_cuenta_tienda BIGINT NOT NULL,
  estado           ENUM('pendiente','aprobada','rechazada') DEFAULT 'pendiente',
  observacion      TEXT,
  creado_en        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (id_cuenta_tienda) REFERENCES PERFIL_TIENDA(id_cuenta),
  INDEX idx_sol_tienda_estado (estado, creado_en)
);

CREATE TABLE SOLICITUD_REPARTIDOR (
  id_solicitud   BIGINT PRIMARY KEY,
  id_cuenta_rep  BIGINT NOT NULL,
  estado         ENUM('pendiente','aprobada','rechazada') DEFAULT 'pendiente',
  observacion    TEXT,
  creado_en      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (id_cuenta_rep) REFERENCES PERFIL_REPARTIDOR(id_cuenta),
  INDEX idx_sol_rep_estado (estado, creado_en)
);

CREATE TABLE AUDIT_LOG (
  id_log           BIGINT PRIMARY KEY,
  id_cuenta_actor  BIGINT,                   -- CUENTA que ejecuta la acción
  recurso          VARCHAR(50),              -- 'tienda','repartidor','pedido','producto', etc.
  id_recurso       BIGINT,
  accion           VARCHAR(50),              -- 'aprobar','rechazar','suspender','crear','actualizar', etc.
  detalle          TEXT,
  creado_en        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_recurso (recurso, id_recurso, creado_en)
);

CREATE TABLE ALERTA_STOCK (
  id_alerta   BIGINT PRIMARY KEY,
  id_producto BIGINT NOT NULL,
  stock       INT NOT NULL,
  generado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  atendido    BOOLEAN DEFAULT FALSE,
  FOREIGN KEY (id_producto) REFERENCES PRODUCTO(id_producto),
  INDEX idx_alerta_producto (id_producto, atendido)
);

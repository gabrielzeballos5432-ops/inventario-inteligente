-- SCRIPT BASE DE DATOS - SALÓN DE BELLEZA ZOOM

-- 1. Tabla de rol
CREATE TABLE rol (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT
);

-- 2. Tabla de marca
CREATE TABLE marca (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL, -- Sin UNIQUE: la unicidad no distingue mayusculas (ver indice LOWER)
    activo BOOLEAN NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX uq_marca_nombre_lower ON marca(LOWER(nombre));

-- 3. Tabla de proveedor
CREATE TABLE proveedor (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    contacto VARCHAR(100),
    telefono VARCHAR(20),
    email VARCHAR(100),
    activo BOOLEAN NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX uq_proveedor_nombre_lower ON proveedor(LOWER(nombre));

-- 4. Tabla de categoría
CREATE TABLE categoria (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL, -- Sin UNIQUE: la unicidad no distingue mayusculas (ver indice LOWER)
    padre_id INTEGER REFERENCES categoria(id) ON DELETE SET NULL,
    activo BOOLEAN NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX uq_categoria_nombre_lower ON categoria(LOWER(nombre));

-- 5. Tabla de usuario (Sin UNIQUE normal, ya que hay índice LOWER)
CREATE TABLE usuario (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL, -- Quitado UNIQUE
    password_hash VARCHAR(255) NOT NULL,
    rol_id INTEGER NOT NULL REFERENCES rol(id),
    pago_por_hora DECIMAL(10,2),
    porcentaje_comision DECIMAL(5,2),
    activo BOOLEAN NOT NULL DEFAULT true,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_usuario_pago_por_hora CHECK (
        pago_por_hora IS NULL OR pago_por_hora > 0
    ),
    CONSTRAINT chk_usuario_porcentaje_comision CHECK (
        porcentaje_comision IS NULL OR porcentaje_comision BETWEEN 0 AND 100
    )
);

-- 6. Tabla de producto (Stock mínimo obligatorio)
CREATE TABLE producto (
    id SERIAL PRIMARY KEY,
    sku VARCHAR(50) UNIQUE,
    codigo_barras VARCHAR(50) UNIQUE,
    nombre VARCHAR(200) NOT NULL,
    descripcion TEXT,
    categoria_id INTEGER REFERENCES categoria(id),
    marca_id INTEGER REFERENCES marca(id),
    proveedor_id INTEGER REFERENCES proveedor(id),
    precio_compra DECIMAL(10,2) NOT NULL,
    precio_venta DECIMAL(10,2) NOT NULL,
    precio_mayor DECIMAL(10,2), -- precio al por mayor; NULL = sin precio mayorista
    stock_minimo INTEGER NOT NULL DEFAULT 5, -- NOT NULL
    imagen_url TEXT,
    activo BOOLEAN NOT NULL DEFAULT true,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_precio_compra_no_negativo CHECK (precio_compra >= 0),
    CONSTRAINT chk_precio_venta_no_negativo CHECK (precio_venta >= 0),
    CONSTRAINT chk_precio_mayor_positivo CHECK (precio_mayor IS NULL OR precio_mayor > 0),
    CONSTRAINT chk_stock_minimo_no_negativo CHECK (stock_minimo >= 0)
);

-- 7. Tabla de inventario
CREATE TABLE inventario (
    id SERIAL PRIMARY KEY,
    producto_id INTEGER UNIQUE NOT NULL REFERENCES producto(id) ON DELETE CASCADE,
    cantidad INTEGER NOT NULL DEFAULT 0,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_inventario_cantidad_no_negativa CHECK (cantidad >= 0)
);

-- 8. Tabla de sesión_cámara
CREATE TABLE sesion_camara (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER REFERENCES usuario(id),
    tipo_operacion VARCHAR(50) NOT NULL CHECK (tipo_operacion IN ('entrada', 'salida', 'conteo')),
    fecha_inicio TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin TIMESTAMPTZ,
    productos_detectados INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_productos_detectados_no_negativo CHECK (productos_detectados >= 0),
    CONSTRAINT chk_fechas_sesion CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);

-- 9. Clientes, sesiones de caja y ventas
CREATE TABLE cliente (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    telefono VARCHAR(30),
    email VARCHAR(150),
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX uq_cliente_email_lower ON cliente (LOWER(email));

CREATE TABLE sesion_caja (
    id SERIAL PRIMARY KEY,
    usuario_apertura_id INTEGER NOT NULL REFERENCES usuario(id),
    usuario_cierre_id INTEGER REFERENCES usuario(id),
    fecha_apertura TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_cierre TIMESTAMPTZ,
    monto_inicial DECIMAL(12,2) NOT NULL CHECK (monto_inicial >= 0),
    monto_esperado_cierre DECIMAL(12,2)
        CHECK (monto_esperado_cierre IS NULL OR monto_esperado_cierre >= 0),
    monto_efectivo_contado DECIMAL(12,2)
        CHECK (monto_efectivo_contado IS NULL OR monto_efectivo_contado >= 0),
    observacion_cierre VARCHAR(250),
    estado VARCHAR(20) NOT NULL DEFAULT 'abierta'
        CHECK (estado IN ('abierta', 'cerrada')),
    CONSTRAINT chk_sesion_caja_fechas
        CHECK (fecha_cierre IS NULL OR fecha_cierre >= fecha_apertura)
);
CREATE UNIQUE INDEX uq_sesion_caja_usuario_abierta
    ON sesion_caja(usuario_apertura_id) WHERE estado = 'abierta';

-- 10. Venta, detalle y pago
CREATE TABLE venta (
    id SERIAL PRIMARY KEY,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_id INTEGER NOT NULL REFERENCES usuario(id),
    cliente_id INTEGER REFERENCES cliente(id),
    sesion_caja_id INTEGER REFERENCES sesion_caja(id),
    clave_idempotencia VARCHAR(100),
    huella_solicitud VARCHAR(64),
    tipo_venta VARCHAR(20) NOT NULL DEFAULT 'minorista'
        CHECK (tipo_venta IN ('minorista', 'mayorista')),
    total DECIMAL(12,2) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'completada',
    anulada_en TIMESTAMPTZ,
    anulada_por_usuario_id INTEGER REFERENCES usuario(id),
    motivo_anulacion VARCHAR(250),
    CONSTRAINT chk_venta_total_no_negativo CHECK (total >= 0),
    CONSTRAINT chk_venta_estado CHECK (estado IN ('completada', 'anulada'))
);

CREATE TABLE venta_detalle (
    id SERIAL PRIMARY KEY,
    venta_id INTEGER NOT NULL REFERENCES venta(id) ON DELETE RESTRICT,
    producto_id INTEGER NOT NULL REFERENCES producto(id) ON DELETE RESTRICT,
    producto_nombre VARCHAR(200) NOT NULL,
    producto_sku VARCHAR(50),
    cantidad INTEGER NOT NULL,
    precio_lista_unitario DECIMAL(10,2) NOT NULL,
    precio_unitario_negociado DECIMAL(10,2) NOT NULL,
    total_linea DECIMAL(12,2) NOT NULL,
    costo_unitario_bob_aplicado DECIMAL(14,4),
    costo_total_bob_aplicado DECIMAL(14,2),
    tipo_promocion VARCHAR(20),
    observacion_promocion VARCHAR(200),
    CONSTRAINT chk_venta_detalle_cantidad_positiva CHECK (cantidad > 0),
    CONSTRAINT chk_venta_detalle_precio_lista_no_negativo CHECK (precio_lista_unitario >= 0),
    CONSTRAINT chk_venta_detalle_precio_negociado_no_negativo CHECK (precio_unitario_negociado >= 0),
    CONSTRAINT chk_venta_detalle_total_no_negativo CHECK (total_linea >= 0),
    CONSTRAINT chk_venta_detalle_costo_unitario CHECK (
        costo_unitario_bob_aplicado IS NULL OR costo_unitario_bob_aplicado >= 0
    ),
    CONSTRAINT chk_venta_detalle_costo_total CHECK (
        costo_total_bob_aplicado IS NULL OR costo_total_bob_aplicado >= 0
    ),
    CONSTRAINT chk_venta_detalle_tipo_promocion CHECK (
        tipo_promocion IS NULL OR tipo_promocion IN ('oferta', 'combo', 'liquidacion')
    )
);

CREATE TABLE pago_venta (
    id SERIAL PRIMARY KEY,
    venta_id INTEGER NOT NULL REFERENCES venta(id) ON DELETE RESTRICT,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metodo_pago VARCHAR(20) NOT NULL,
    monto DECIMAL(12,2) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'confirmado',
    referencia VARCHAR(100),
    sesion_caja_id INTEGER REFERENCES sesion_caja(id),
    CONSTRAINT chk_pago_venta_monto_positivo CHECK (monto > 0),
    CONSTRAINT chk_pago_venta_metodo CHECK (metodo_pago IN ('efectivo', 'qr')),
    CONSTRAINT chk_pago_venta_estado CHECK (estado IN ('confirmado', 'anulado'))
);

-- Monedas y compras: las cotizaciones se conservan por compra para auditoría.
CREATE TABLE moneda (
    codigo VARCHAR(3) PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    simbolo VARCHAR(10),
    pais VARCHAR(80),
    decimales INTEGER NOT NULL DEFAULT 2,
    activa BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT chk_moneda_decimales CHECK (decimales BETWEEN 0 AND 4)
);

CREATE TABLE compra (
    id SERIAL PRIMARY KEY,
    proveedor_id INTEGER REFERENCES proveedor(id),
    usuario_id INTEGER NOT NULL REFERENCES usuario(id),
    moneda_codigo VARCHAR(3) NOT NULL REFERENCES moneda(codigo),
    tipo_cambio_ext DECIMAL(18,6) NOT NULL CHECK (tipo_cambio_ext > 0),
    tipo_cambio_bob DECIMAL(18,6) NOT NULL CHECK (tipo_cambio_bob > 0),
    numero_factura VARCHAR(100),
    fecha_factura DATE,
    subtotal_moneda DECIMAL(18,4) NOT NULL CHECK (subtotal_moneda >= 0),
    descuento_moneda DECIMAL(18,4) NOT NULL DEFAULT 0
        CHECK (descuento_moneda >= 0 AND descuento_moneda <= subtotal_moneda),
    base_costo_adicional_moneda DECIMAL(18,4) NOT NULL
        CHECK (base_costo_adicional_moneda >= 0),
    porcentaje_manipulacion_envio DECIMAL(5,2) NOT NULL DEFAULT 0
        CHECK (porcentaje_manipulacion_envio >= 0),
    costo_manipulacion_envio_moneda DECIMAL(18,4) NOT NULL
        CHECK (costo_manipulacion_envio_moneda >= 0),
    total_moneda DECIMAL(18,4) NOT NULL CHECK (total_moneda >= 0),
    total_bob DECIMAL(14,2) NOT NULL CHECK (total_bob >= 0),
    imagen_factura_url TEXT,
    estado VARCHAR(20) NOT NULL DEFAULT 'registrada'
        CHECK (estado IN ('registrada', 'anulada')),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE compra_detalle (
    id SERIAL PRIMARY KEY,
    compra_id INTEGER NOT NULL REFERENCES compra(id) ON DELETE RESTRICT,
    producto_id INTEGER NOT NULL REFERENCES producto(id) ON DELETE RESTRICT,
    descripcion_factura VARCHAR(250),
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    costo_unitario_moneda DECIMAL(18,6) NOT NULL
        CHECK (costo_unitario_moneda >= 0),
    subtotal_linea_moneda DECIMAL(18,4) NOT NULL
        CHECK (subtotal_linea_moneda >= 0),
    costo_unitario_final_bob DECIMAL(14,4) NOT NULL
        CHECK (costo_unitario_final_bob >= 0),
    CONSTRAINT uq_compra_producto UNIQUE (compra_id, producto_id)
);

-- 11. Tabla de movimiento (con restricción matemática)
CREATE TABLE movimiento (
    id SERIAL PRIMARY KEY,
    producto_id INTEGER NOT NULL REFERENCES producto(id),
    usuario_id INTEGER REFERENCES usuario(id),
    sesion_id INTEGER REFERENCES sesion_camara(id) ON DELETE SET NULL,
    venta_detalle_id INTEGER REFERENCES venta_detalle(id) ON DELETE RESTRICT,
    compra_detalle_id INTEGER REFERENCES compra_detalle(id) ON DELETE RESTRICT,
    movimiento_revertido_id INTEGER REFERENCES movimiento(id) ON DELETE RESTRICT,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('entrada', 'salida', 'ajuste')),
    cantidad_anterior INTEGER NOT NULL CHECK (cantidad_anterior >= 0),
    cantidad INTEGER NOT NULL,
    stock_resultante INTEGER NOT NULL,
    origen VARCHAR(10) NOT NULL CHECK (origen IN ('manual', 'ia')),
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_movimiento_cantidad_positiva CHECK (cantidad > 0 OR tipo = 'ajuste'),
    CONSTRAINT chk_stock_resultante_no_negativo CHECK (stock_resultante >= 0),
    -- RESTRICCIÓN MATEMÁTICA (La joya de la corona)
    CONSTRAINT chk_consistencia_movimiento CHECK (
        (tipo = 'entrada' AND stock_resultante = cantidad_anterior + cantidad)
        OR
        (tipo = 'salida' AND stock_resultante = cantidad_anterior - cantidad)
        OR
        (tipo = 'ajuste')
    ),
    CONSTRAINT uq_movimiento_compra_detalle UNIQUE (compra_detalle_id),
    CONSTRAINT uq_movimiento_venta_detalle UNIQUE (venta_detalle_id),
    CONSTRAINT chk_movimiento_un_solo_documento CHECK (
        venta_detalle_id IS NULL OR compra_detalle_id IS NULL
    ),
    CONSTRAINT chk_movimiento_reversion_tipo CHECK (
        movimiento_revertido_id IS NULL OR tipo IN ('entrada', 'salida')
    )
);

-- 12. Tabla de detección
CREATE TABLE deteccion (
    id SERIAL PRIMARY KEY,
    sesion_id INTEGER NOT NULL REFERENCES sesion_camara(id) ON DELETE CASCADE,
    producto_id INTEGER REFERENCES producto(id),
    confianza DECIMAL(5,4) NOT NULL,
    imagen_url TEXT,
    detectado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_confianza_rango CHECK (confianza BETWEEN 0 AND 1)
);

-- Asistencia y liquidación de sueldos para usuarios con rol vendedor.
CREATE TABLE registro_hora (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER NOT NULL REFERENCES usuario(id),
    fecha DATE NOT NULL,
    hora_entrada TIME NOT NULL,
    hora_salida TIME,
    confirmado_por_usuario_id INTEGER REFERENCES usuario(id),
    fecha_confirmacion TIMESTAMPTZ,
    CONSTRAINT chk_registro_hora_intervalo CHECK (
        hora_salida IS NULL OR hora_salida > hora_entrada
    ),
    CONSTRAINT uq_registro_hora_usuario_fecha UNIQUE (usuario_id, fecha)
);

CREATE TABLE liquidacion_sueldo (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER NOT NULL REFERENCES usuario(id),
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    horas_trabajadas DECIMAL(8,2) NOT NULL CHECK (horas_trabajadas >= 0),
    pago_por_hora_aplicado DECIMAL(10,2) NOT NULL
        CHECK (pago_por_hora_aplicado > 0),
    porcentaje_comision_aplicado DECIMAL(5,2) NOT NULL
        CHECK (porcentaje_comision_aplicado BETWEEN 0 AND 100),
    total_pago_horas DECIMAL(12,2) NOT NULL CHECK (total_pago_horas >= 0),
    total_comision DECIMAL(12,2) NOT NULL CHECK (total_comision >= 0),
    total_bonos DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (total_bonos >= 0),
    total_pagado DECIMAL(12,2) NOT NULL CHECK (total_pagado >= 0),
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente'
        CHECK (estado IN ('pendiente', 'pagado')),
    fecha_pago TIMESTAMPTZ,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_liquidacion_periodo CHECK (fecha_fin >= fecha_inicio),
    CONSTRAINT uq_liquidacion_usuario_periodo
        UNIQUE (usuario_id, fecha_inicio, fecha_fin)
);

CREATE TABLE bono_sueldo (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER NOT NULL REFERENCES usuario(id),
    liquidacion_sueldo_id INTEGER
        REFERENCES liquidacion_sueldo(id) ON DELETE RESTRICT,
    tipo_bono VARCHAR(20) NOT NULL
        CHECK (tipo_bono IN ('live', 'almuerzo', 'navidad', 'otro')),
    descripcion VARCHAR(250),
    monto DECIMAL(12,2) NOT NULL CHECK (monto > 0),
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE categoria_gasto (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    periodicidad VARCHAR(20) NOT NULL DEFAULT 'sin_periodicidad',
    tipo_importe VARCHAR(10) NOT NULL DEFAULT 'variable',
    monto_habitual NUMERIC(14,2),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_categoria_gasto_periodicidad CHECK (
        periodicidad IN ('sin_periodicidad', 'mensual', 'semanal', 'anual')
    ),
    CONSTRAINT chk_categoria_gasto_tipo_importe CHECK (tipo_importe IN ('fijo', 'variable')),
    CONSTRAINT chk_categoria_gasto_monto CHECK (
        monto_habitual IS NULL OR (monto_habitual > 0 AND tipo_importe = 'fijo')
    )
);
CREATE UNIQUE INDEX uq_categoria_gasto_nombre_lower ON categoria_gasto(lower(nombre));
INSERT INTO categoria_gasto (nombre, periodicidad, tipo_importe) VALUES
    ('Luz', 'mensual', 'variable'), ('Agua', 'mensual', 'fijo'),
    ('Wifi', 'mensual', 'fijo'), ('Alquiler', 'mensual', 'fijo'),
    ('Scotch', 'sin_periodicidad', 'variable'),
    ('Papel para tickets', 'sin_periodicidad', 'variable'),
    ('Etiquetas', 'sin_periodicidad', 'variable');

CREATE TABLE gasto (
    id SERIAL PRIMARY KEY,
    categoria VARCHAR(100) NOT NULL,
    categoria_gasto_id INTEGER REFERENCES categoria_gasto(id) ON DELETE RESTRICT,
    concepto VARCHAR(200) NOT NULL,
    proveedor_id INTEGER REFERENCES proveedor(id),
    usuario_id INTEGER NOT NULL REFERENCES usuario(id),
    fecha_documento DATE,
    periodo_desde DATE,
    periodo_hasta DATE,
    numero_documento VARCHAR(100),
    moneda_codigo VARCHAR(3) NOT NULL REFERENCES moneda(codigo),
    monto DECIMAL(18,4) NOT NULL CHECK (monto > 0),
    tipo_cambio_ext DECIMAL(18,6) NOT NULL CHECK (tipo_cambio_ext > 0),
    tipo_cambio_bob DECIMAL(18,6) NOT NULL CHECK (tipo_cambio_bob > 0),
    monto_bob DECIMAL(14,2) NOT NULL CHECK (monto_bob > 0),
    soporte_url TEXT,
    anulado_en TIMESTAMPTZ,
    anulada_por_usuario_id INTEGER REFERENCES usuario(id),
    motivo_anulacion VARCHAR(250),
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente'
        CHECK (estado IN ('pendiente', 'pagado', 'anulado')),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_gasto_periodo CHECK (
        periodo_hasta IS NULL OR periodo_desde IS NULL OR periodo_hasta >= periodo_desde
    )
);

CREATE TABLE pago_gasto (
    id SERIAL PRIMARY KEY,
    gasto_id INTEGER NOT NULL REFERENCES gasto(id) ON DELETE RESTRICT,
    sesion_caja_id INTEGER REFERENCES sesion_caja(id),
    fecha_pago TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto DECIMAL(18,4) NOT NULL CHECK (monto > 0),
    monto_bob DECIMAL(14,2) NOT NULL CHECK (monto_bob > 0),
    metodo_pago VARCHAR(30) NOT NULL
        CHECK (metodo_pago IN ('efectivo', 'transferencia', 'qr', 'otro')),
    referencia VARCHAR(150)
);

-- Índices para rendimiento
CREATE INDEX idx_producto_categoria ON producto(categoria_id);
CREATE INDEX idx_producto_marca ON producto(marca_id);
CREATE INDEX idx_producto_proveedor ON producto(proveedor_id);
CREATE INDEX idx_producto_nombre ON producto(nombre);
CREATE INDEX idx_movimiento_producto ON movimiento(producto_id);
CREATE INDEX idx_movimiento_usuario ON movimiento(usuario_id);
CREATE INDEX idx_movimiento_sesion ON movimiento(sesion_id);
CREATE INDEX idx_movimiento_fecha ON movimiento(creado_en);
CREATE INDEX idx_deteccion_sesion ON deteccion(sesion_id);
CREATE INDEX idx_deteccion_producto ON deteccion(producto_id);
CREATE INDEX idx_usuario_rol ON usuario(rol_id);
CREATE INDEX idx_categoria_padre ON categoria(padre_id);
CREATE INDEX idx_sesion_usuario ON sesion_camara(usuario_id);
CREATE INDEX idx_venta_usuario ON venta(usuario_id);
CREATE INDEX idx_venta_fecha ON venta(fecha_creacion);
CREATE INDEX idx_venta_detalle_venta ON venta_detalle(venta_id);
CREATE INDEX idx_venta_detalle_producto ON venta_detalle(producto_id);
CREATE INDEX idx_pago_venta_venta ON pago_venta(venta_id);
CREATE INDEX idx_pago_venta_sesion_caja ON pago_venta(sesion_caja_id);
CREATE INDEX idx_venta_cliente ON venta(cliente_id);
CREATE INDEX idx_venta_sesion_caja ON venta(sesion_caja_id);
CREATE UNIQUE INDEX uq_venta_clave_idempotencia
    ON venta(usuario_id, clave_idempotencia)
    WHERE clave_idempotencia IS NOT NULL;
CREATE INDEX idx_sesion_caja_fecha ON sesion_caja(fecha_apertura);
CREATE INDEX idx_bono_sueldo_usuario_fecha
    ON bono_sueldo(usuario_id, fecha_registro);
CREATE INDEX idx_gasto_periodo_categoria ON gasto(periodo_desde, categoria);
CREATE INDEX idx_gasto_proveedor ON gasto(proveedor_id);
CREATE INDEX idx_gasto_categoria_gasto ON gasto(categoria_gasto_id);
CREATE INDEX idx_pago_gasto_gasto_fecha ON pago_gasto(gasto_id, fecha_pago);
CREATE INDEX idx_pago_gasto_sesion ON pago_gasto(sesion_caja_id);
CREATE INDEX idx_compra_proveedor_fecha ON compra(proveedor_id, fecha_creacion);
CREATE INDEX idx_compra_fecha ON compra(fecha_creacion);
CREATE INDEX idx_compra_detalle_producto ON compra_detalle(producto_id);
CREATE INDEX idx_registro_hora_fecha ON registro_hora(fecha);
CREATE INDEX idx_liquidacion_usuario_periodo
    ON liquidacion_sueldo(usuario_id, fecha_inicio, fecha_fin);

-- Índice único para email en minúsculas
CREATE UNIQUE INDEX uq_usuario_email_lower ON usuario(LOWER(email));

-- Datos iniciales
INSERT INTO rol (nombre) VALUES ('administrador'), ('vendedor') ON CONFLICT (nombre) DO NOTHING;
INSERT INTO categoria (nombre) VALUES ('General'), ('Tintes'), ('Peróxidos') ON CONFLICT (nombre) DO NOTHING;
INSERT INTO marca (nombre) VALUES ('Schwarzkopf'), ('Loreal') ON CONFLICT (nombre) DO NOTHING;
INSERT INTO moneda (codigo, nombre, simbolo, pais, decimales)
VALUES
    ('BOB', 'Boliviano', 'Bs', 'Bolivia', 2),
    ('USD', 'Dólar estadounidense', '$', 'Estados Unidos', 2)
ON CONFLICT (codigo) DO NOTHING;
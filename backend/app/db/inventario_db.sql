-- SCRIPT BASE DE DATOS - SALÓN DE BELLEZA ZOOM

-- 1. Tabla de roles
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT
);

-- 2. Tabla de marcas
CREATE TABLE marcas (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL, -- Sin UNIQUE: la unicidad no distingue mayusculas (ver indice LOWER)
    activo BOOLEAN NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX uq_marcas_nombre_lower ON marcas(LOWER(nombre));

-- 3. Tabla de proveedores
CREATE TABLE proveedores (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    contacto VARCHAR(100),
    telefono VARCHAR(20),
    email VARCHAR(100),
    activo BOOLEAN NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX uq_proveedores_nombre_lower ON proveedores(LOWER(nombre));

-- 4. Tabla de categorías
CREATE TABLE categorias (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL, -- Sin UNIQUE: la unicidad no distingue mayusculas (ver indice LOWER)
    padre_id INTEGER REFERENCES categorias(id) ON DELETE SET NULL,
    activo BOOLEAN NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX uq_categorias_nombre_lower ON categorias(LOWER(nombre));

-- 5. Tabla de usuarios (Sin UNIQUE normal, ya que hay índice LOWER)
CREATE TABLE usuarios (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL, -- Quitado UNIQUE
    password_hash VARCHAR(255) NOT NULL,
    rol_id INTEGER NOT NULL REFERENCES roles(id),
    activo BOOLEAN NOT NULL DEFAULT true,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 6. Tabla de productos (Stock mínimo obligatorio)
CREATE TABLE productos (
    id SERIAL PRIMARY KEY,
    sku VARCHAR(50) UNIQUE,
    codigo_barras VARCHAR(50) UNIQUE,
    nombre VARCHAR(200) NOT NULL,
    descripcion TEXT,
    categoria_id INTEGER REFERENCES categorias(id),
    marca_id INTEGER REFERENCES marcas(id),
    proveedor_id INTEGER REFERENCES proveedores(id),
    precio_compra DECIMAL(10,2) NOT NULL,
    precio_venta DECIMAL(10,2) NOT NULL,
    stock_minimo INTEGER NOT NULL DEFAULT 5, -- NOT NULL
    imagen_url TEXT,
    activo BOOLEAN NOT NULL DEFAULT true,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_precio_compra_no_negativo CHECK (precio_compra >= 0),
    CONSTRAINT chk_precio_venta_no_negativo CHECK (precio_venta >= 0),
    CONSTRAINT chk_stock_minimo_no_negativo CHECK (stock_minimo >= 0)
);

-- 7. Tabla de inventario
CREATE TABLE inventario (
    id SERIAL PRIMARY KEY,
    producto_id INTEGER UNIQUE NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
    cantidad INTEGER NOT NULL DEFAULT 0,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_inventario_cantidad_no_negativa CHECK (cantidad >= 0)
);

-- 8. Tabla de sesiones_cámara
CREATE TABLE sesiones_camara (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER REFERENCES usuarios(id),
    tipo_operacion VARCHAR(50) NOT NULL CHECK (tipo_operacion IN ('entrada', 'salida', 'conteo')),
    fecha_inicio TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin TIMESTAMPTZ,
    productos_detectados INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_productos_detectados_no_negativo CHECK (productos_detectados >= 0),
    CONSTRAINT chk_fechas_sesion CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);

-- 9. Tabla de movimientos (con restricción matemática)
CREATE TABLE movimientos (
    id SERIAL PRIMARY KEY,
    producto_id INTEGER NOT NULL REFERENCES productos(id),
    usuario_id INTEGER REFERENCES usuarios(id),
    sesion_id INTEGER REFERENCES sesiones_camara(id) ON DELETE SET NULL,
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
    )
);

-- 10. Tabla de detecciones
CREATE TABLE detecciones (
    id SERIAL PRIMARY KEY,
    sesion_id INTEGER NOT NULL REFERENCES sesiones_camara(id) ON DELETE CASCADE,
    producto_id INTEGER REFERENCES productos(id),
    confianza DECIMAL(5,4) NOT NULL,
    imagen_url TEXT,
    detectado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_confianza_rango CHECK (confianza BETWEEN 0 AND 1)
);

-- Índices para rendimiento
CREATE INDEX idx_productos_categoria ON productos(categoria_id);
CREATE INDEX idx_productos_marca ON productos(marca_id);
CREATE INDEX idx_productos_proveedor ON productos(proveedor_id);
CREATE INDEX idx_productos_nombre ON productos(nombre);
CREATE INDEX idx_movimientos_producto ON movimientos(producto_id);
CREATE INDEX idx_movimientos_usuario ON movimientos(usuario_id);
CREATE INDEX idx_movimientos_sesion ON movimientos(sesion_id);
CREATE INDEX idx_movimientos_fecha ON movimientos(creado_en);
CREATE INDEX idx_detecciones_sesion ON detecciones(sesion_id);
CREATE INDEX idx_detecciones_producto ON detecciones(producto_id);
CREATE INDEX idx_usuarios_rol ON usuarios(rol_id);
CREATE INDEX idx_categorias_padre ON categorias(padre_id);
CREATE INDEX idx_sesiones_usuario ON sesiones_camara(usuario_id);

-- Índice único para email en minúsculas
CREATE UNIQUE INDEX uq_usuarios_email_lower ON usuarios(LOWER(email));

-- Datos iniciales
INSERT INTO roles (nombre) VALUES ('administrador'), ('vendedor') ON CONFLICT (nombre) DO NOTHING;
INSERT INTO categorias (nombre) VALUES ('General'), ('Tintes'), ('Peróxidos') ON CONFLICT (nombre) DO NOTHING;
INSERT INTO marcas (nombre) VALUES ('Schwarzkopf'), ('Loreal') ON CONFLICT (nombre) DO NOTHING;
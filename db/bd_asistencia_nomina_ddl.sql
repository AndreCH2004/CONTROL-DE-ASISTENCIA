-- ============================================================================
-- bd_asistencia_nomina - creación del esquema para Azure SQL Database
-- Ejecutar en el Query editor del portal de Azure, conectado a la base
-- bd_asistencia_nomina (NO a master). Ejecutar una sola vez.
-- ============================================================================

-- Protección: si el esquema ya existe, se detiene sin modificar nada.
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'roles')
    THROW 50000, 'El esquema ya existe. Para recrearlo, elimine primero la base de datos.', 1;

-- 1. roles (catálogo de perfiles de acceso)
CREATE TABLE roles (
    id              INT           IDENTITY(1,1) NOT NULL,
    nombre          VARCHAR(30)   NOT NULL,
    descripcion     VARCHAR(150)  NULL,
    estado          BIT           NOT NULL CONSTRAINT df_roles_estado DEFAULT 1,
    creado_el       DATETIME2(0)  NOT NULL CONSTRAINT df_roles_creado_el DEFAULT SYSDATETIME(),
    actualizado_el  DATETIME2(0)  NULL,
    id_usuario      INT           NULL,            -- NULL solo para los registros semilla
    CONSTRAINT pk_roles        PRIMARY KEY (id),
    CONSTRAINT uq_roles_nombre UNIQUE (nombre)
);

-- 2. usuarios (personal que opera el sistema: RRHH, supervisión y la tablet)
CREATE TABLE usuarios (
    id              INT           IDENTITY(1,1) NOT NULL,
    id_rol          INT           NOT NULL,
    nombre_usuario  VARCHAR(40)   NOT NULL,
    correo          VARCHAR(120)  NOT NULL,
    clave_hash      VARCHAR(255)  NOT NULL,        -- Bcrypt; nunca texto plano
    estado          BIT           NOT NULL CONSTRAINT df_usuarios_estado DEFAULT 1,
    creado_el       DATETIME2(0)  NOT NULL CONSTRAINT df_usuarios_creado_el DEFAULT SYSDATETIME(),
    actualizado_el  DATETIME2(0)  NULL,
    id_usuario      INT           NULL,            -- NULL solo para los registros semilla
    CONSTRAINT pk_usuarios                PRIMARY KEY (id),
    CONSTRAINT uq_usuarios_nombre_usuario UNIQUE (nombre_usuario),
    CONSTRAINT uq_usuarios_correo         UNIQUE (correo),
    CONSTRAINT fk_usuarios_rol            FOREIGN KEY (id_rol)     REFERENCES roles (id),
    CONSTRAINT fk_usuarios_usuario        FOREIGN KEY (id_usuario) REFERENCES usuarios (id)
);

-- Cierra la referencia circular roles -> usuarios
ALTER TABLE roles
    ADD CONSTRAINT fk_roles_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id);

-- 3. turnos (horario contra el que se calcula la tardanza)
CREATE TABLE turnos (
    id              INT           IDENTITY(1,1) NOT NULL,
    nombre          VARCHAR(40)   NOT NULL,
    hora_inicio     TIME(0)       NOT NULL,
    hora_fin        TIME(0)       NOT NULL,
    estado          BIT           NOT NULL CONSTRAINT df_turnos_estado DEFAULT 1,
    creado_el       DATETIME2(0)  NOT NULL CONSTRAINT df_turnos_creado_el DEFAULT SYSDATETIME(),
    actualizado_el  DATETIME2(0)  NULL,
    id_usuario      INT           NOT NULL,
    CONSTRAINT pk_turnos        PRIMARY KEY (id),
    CONSTRAINT uq_turnos_nombre UNIQUE (nombre),
    CONSTRAINT ck_turnos_horas  CHECK (hora_fin > hora_inicio),
    CONSTRAINT fk_turnos_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id)
);

-- 4. frentes_obra (lugares donde se registra la asistencia)
CREATE TABLE frentes_obra (
    id              INT           IDENTITY(1,1) NOT NULL,
    nombre          VARCHAR(80)   NOT NULL,
    distrito        VARCHAR(60)   NOT NULL,
    direccion       VARCHAR(150)  NULL,
    estado          BIT           NOT NULL CONSTRAINT df_frentes_obra_estado DEFAULT 1,
    creado_el       DATETIME2(0)  NOT NULL CONSTRAINT df_frentes_obra_creado_el DEFAULT SYSDATETIME(),
    actualizado_el  DATETIME2(0)  NULL,
    id_usuario      INT           NOT NULL,
    CONSTRAINT pk_frentes_obra         PRIMARY KEY (id),
    CONSTRAINT uq_frentes_obra_nombre  UNIQUE (nombre),
    CONSTRAINT fk_frentes_obra_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id)
);

-- 5. empleados (código de empleado = contenido del QR del fotocheck)
CREATE TABLE empleados (
    id              INT           IDENTITY(1,1) NOT NULL,
    id_turno        INT           NOT NULL,
    codigo          VARCHAR(10)   NOT NULL,
    nombre          VARCHAR(120)  NOT NULL,
    estado          BIT           NOT NULL CONSTRAINT df_empleados_estado DEFAULT 1,
    creado_el       DATETIME2(0)  NOT NULL CONSTRAINT df_empleados_creado_el DEFAULT SYSDATETIME(),
    actualizado_el  DATETIME2(0)  NULL,
    id_usuario      INT           NOT NULL,
    CONSTRAINT pk_empleados         PRIMARY KEY (id),
    CONSTRAINT uq_empleados_codigo  UNIQUE (codigo),
    CONSTRAINT fk_empleados_turno   FOREIGN KEY (id_turno)   REFERENCES turnos (id),
    CONSTRAINT fk_empleados_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id)
);

-- 6. registros_asistencia (un registro por empleado y por día)
CREATE TABLE registros_asistencia (
    id                INT           IDENTITY(1,1) NOT NULL,
    id_empleado       INT           NOT NULL,
    id_frente_obra    INT           NOT NULL,
    fecha_registro    DATE          NOT NULL,
    hora_ingreso      TIME(0)       NULL,
    hora_salida       TIME(0)       NULL,
    horas_trabajadas  DECIMAL(5,2)  NOT NULL CONSTRAINT df_registros_asistencia_horas DEFAULT 0,
    minutos_tardanza  INT           NOT NULL CONSTRAINT df_registros_asistencia_tardanza DEFAULT 0,
    es_falta          BIT           NOT NULL CONSTRAINT df_registros_asistencia_falta DEFAULT 0,
    estado            BIT           NOT NULL CONSTRAINT df_registros_asistencia_estado DEFAULT 1,
    creado_el         DATETIME2(0)  NOT NULL CONSTRAINT df_registros_asistencia_creado_el DEFAULT SYSDATETIME(),
    actualizado_el    DATETIME2(0)  NULL,
    id_usuario        INT           NOT NULL,      -- usuario que originó el registro (p. ej. la tablet)
    CONSTRAINT pk_registros_asistencia PRIMARY KEY (id),
    CONSTRAINT uq_registros_asistencia_empleado_fecha UNIQUE (id_empleado, fecha_registro),
    CONSTRAINT fk_registros_asistencia_empleado    FOREIGN KEY (id_empleado)    REFERENCES empleados (id),
    CONSTRAINT fk_registros_asistencia_frente_obra FOREIGN KEY (id_frente_obra) REFERENCES frentes_obra (id),
    CONSTRAINT fk_registros_asistencia_usuario     FOREIGN KEY (id_usuario)     REFERENCES usuarios (id),
    CONSTRAINT ck_registros_asistencia_horas   CHECK (horas_trabajadas BETWEEN 0 AND 24),
    CONSTRAINT ck_registros_asistencia_tardanza CHECK (minutos_tardanza >= 0),
    CONSTRAINT ck_registros_asistencia_salida  CHECK (hora_salida IS NULL OR hora_ingreso IS NOT NULL),
    CONSTRAINT ck_registros_asistencia_falta   CHECK (es_falta = 0 OR hora_ingreso IS NULL)
);

-- 7. Índices sobre claves foráneas y columnas de consulta frecuente
CREATE INDEX idx_usuarios_rol                     ON usuarios (id_rol);
CREATE INDEX idx_empleados_turno                  ON empleados (id_turno);
CREATE INDEX idx_registros_asistencia_frente_obra ON registros_asistencia (id_frente_obra);
CREATE INDEX idx_registros_asistencia_fecha       ON registros_asistencia (fecha_registro);

-- 8. Datos iniciales (turnos, frentes, empleados y asistencia de ejemplo)
-- Los hashes de usuarios son marcadores: se reemplazan cuando la aplicación tenga inicio de sesión.
INSERT INTO roles (nombre, descripcion) VALUES
    (N'ADMINISTRADOR',       N'Administración general del sistema'),
    (N'RRHH',                N'Consulta y corrección de asistencia'),
    (N'SUPERVISOR',          N'Consulta de asistencia por frente de obra'),
    (N'CONTROL_ASISTENCIA',  N'Cuenta técnica de la tablet de registro de asistencia');

INSERT INTO usuarios (id_rol, nombre_usuario, correo, clave_hash)
SELECT id, N'admin', N'admin@construandina.example', N'$2a$10$REEMPLAZAR_CON_HASH_BCRYPT'
FROM roles WHERE nombre = N'ADMINISTRADOR';

INSERT INTO usuarios (id_rol, nombre_usuario, correo, clave_hash)
SELECT id, N'tablet_asistencia', N'tablet@construandina.example', N'$2a$10$REEMPLAZAR_CON_HASH_BCRYPT'
FROM roles WHERE nombre = N'CONTROL_ASISTENCIA';

INSERT INTO turnos (nombre, hora_inicio, hora_fin, id_usuario)
SELECT v.nombre, v.inicio, v.fin, u.id
FROM (VALUES
        (N'Turno diurno',    '07:00', '16:00'),
        (N'Turno temprano',  '06:00', '15:00')
     ) AS v (nombre, inicio, fin)
CROSS JOIN usuarios u
WHERE u.nombre_usuario = N'admin';

INSERT INTO frentes_obra (nombre, distrito, id_usuario)
SELECT v.nombre, v.distrito, u.id
FROM (VALUES
        (N'Obra San Isidro', N'San Isidro'),
        (N'Obra Surco',      N'Santiago de Surco'),
        (N'Obra La Molina',  N'La Molina')
     ) AS v (nombre, distrito)
CROSS JOIN usuarios u
WHERE u.nombre_usuario = N'admin';

INSERT INTO empleados (codigo, nombre, id_turno, id_usuario)
SELECT v.codigo, v.nombre, t.id, u.id
FROM (VALUES
        (N'EMP-001', N'Juan Ramírez Soto', N'Turno diurno'),
        (N'EMP-002', N'María Castro Díaz', N'Turno diurno'),
        (N'EMP-003', N'Luis Huamán Quispe', N'Turno diurno'),
        (N'EMP-004', N'Rosa Quispe Mamani', N'Turno diurno'),
        (N'EMP-005', N'Carlos Flores Ticona', N'Turno diurno'),
        (N'EMP-006', N'Ana Lucía Torres Vega', N'Turno diurno'),
        (N'EMP-007', N'Pedro Salas Ríos', N'Turno temprano'),
        (N'EMP-008', N'Jorge Ccama Pérez', N'Turno temprano'),
        (N'EMP-009', N'Lucía Mendoza Ruiz', N'Turno temprano'),
        (N'EMP-010', N'Miguel Ángel Ortiz Paredes', N'Turno temprano'),
        (N'EMP-011', N'Elena Gutiérrez Vilca', N'Turno temprano'),
        (N'EMP-012', N'Daniel Sánchez Mora', N'Turno temprano')
     ) AS v (codigo, nombre, turno)
JOIN turnos t ON t.nombre = v.turno
CROSS JOIN usuarios u
WHERE u.nombre_usuario = N'admin';

-- Asistencia de ejemplo: 26 al 29 de octubre de 2026 (una fila por empleado y día).
-- Las horas y tardanzas siguen las reglas de la aplicación.
INSERT INTO registros_asistencia (id_empleado, id_frente_obra, fecha_registro, hora_ingreso, hora_salida,
                                  horas_trabajadas, minutos_tardanza, es_falta, id_usuario)
SELECT e.id, f.id, v.fecha, v.ingreso, v.salida, v.horas, v.tardanza, v.falta, u.id
FROM (VALUES
        ('EMP-001', N'Obra San Isidro', '2026-10-26', '07:25', '16:30', 9.08, 25, 0),
        ('EMP-001', N'Obra San Isidro', '2026-10-27', '06:55', '16:00', 9.08, 0, 0),
        ('EMP-001', N'Obra San Isidro', '2026-10-28', '07:25', '16:05', 8.67, 25, 0),
        ('EMP-001', N'Obra San Isidro', '2026-10-29', '07:25', '16:30', 9.08, 25, 0),
        ('EMP-002', N'Obra Surco', '2026-10-26', '07:15', '16:00', 8.75, 15, 0),
        ('EMP-002', N'Obra Surco', '2026-10-27', NULL, NULL, 0, 0, 1),
        ('EMP-002', N'Obra Surco', '2026-10-28', '07:00', '15:55', 8.92, 0, 0),
        ('EMP-002', N'Obra Surco', '2026-10-29', '07:15', '16:30', 9.25, 15, 0),
        ('EMP-003', N'Obra Surco', '2026-10-26', '07:00', '16:00', 9.00, 0, 0),
        ('EMP-003', N'Obra Surco', '2026-10-27', '07:03', '16:05', 9.03, 3, 0),
        ('EMP-003', N'Obra Surco', '2026-10-28', '07:25', '16:30', 9.08, 25, 0),
        ('EMP-003', N'Obra Surco', '2026-10-29', '07:03', '15:55', 8.87, 3, 0),
        ('EMP-004', N'Obra La Molina', '2026-10-26', '07:00', '16:05', 9.08, 0, 0),
        ('EMP-004', N'Obra La Molina', '2026-10-27', '07:00', '15:55', 8.92, 0, 0),
        ('EMP-004', N'Obra La Molina', '2026-10-28', '07:03', '16:00', 8.95, 3, 0),
        ('EMP-004', N'Obra La Molina', '2026-10-29', '06:55', '16:05', 9.17, 0, 0),
        ('EMP-005', N'Obra La Molina', '2026-10-26', '06:55', '16:05', 9.17, 0, 0),
        ('EMP-005', N'Obra La Molina', '2026-10-27', '07:15', '16:05', 8.83, 15, 0),
        ('EMP-005', N'Obra La Molina', '2026-10-28', '07:00', '16:05', 9.08, 0, 0),
        ('EMP-005', N'Obra La Molina', '2026-10-29', '07:15', '16:12', 8.95, 15, 0),
        ('EMP-006', N'Obra La Molina', '2026-10-26', '07:00', '16:00', 9.00, 0, 0),
        ('EMP-006', N'Obra La Molina', '2026-10-27', '07:25', '16:30', 9.08, 25, 0),
        ('EMP-006', N'Obra La Molina', '2026-10-28', '07:08', '16:05', 8.95, 8, 0),
        ('EMP-006', N'Obra La Molina', '2026-10-29', '07:00', '15:55', 8.92, 0, 0),
        ('EMP-007', N'Obra La Molina', '2026-10-26', '06:15', '15:30', 9.25, 15, 0),
        ('EMP-007', N'Obra La Molina', '2026-10-27', '06:25', '15:00', 8.58, 25, 0),
        ('EMP-007', N'Obra La Molina', '2026-10-28', '06:00', '15:12', 9.20, 0, 0),
        ('EMP-007', N'Obra La Molina', '2026-10-29', '06:25', '15:30', 9.08, 25, 0),
        ('EMP-008', N'Obra Surco', '2026-10-26', '06:08', '15:05', 8.95, 8, 0),
        ('EMP-008', N'Obra Surco', '2026-10-27', '06:00', '14:55', 8.92, 0, 0),
        ('EMP-008', N'Obra Surco', '2026-10-28', NULL, NULL, 0, 0, 1),
        ('EMP-008', N'Obra Surco', '2026-10-29', '06:15', '15:12', 8.95, 15, 0),
        ('EMP-009', N'Obra Surco', '2026-10-26', '06:00', '15:00', 9.00, 0, 0),
        ('EMP-009', N'Obra Surco', '2026-10-27', '06:15', '15:12', 8.95, 15, 0),
        ('EMP-009', N'Obra Surco', '2026-10-28', '06:15', '15:05', 8.83, 15, 0),
        ('EMP-009', N'Obra Surco', '2026-10-29', '05:50', '15:00', 9.17, 0, 0),
        ('EMP-010', N'Obra Surco', '2026-10-26', '05:55', '15:05', 9.17, 0, 0),
        ('EMP-010', N'Obra Surco', '2026-10-27', '06:25', '15:00', 8.58, 25, 0),
        ('EMP-010', N'Obra Surco', '2026-10-28', '06:00', '15:05', 9.08, 0, 0),
        ('EMP-010', N'Obra Surco', '2026-10-29', '06:15', '14:55', 8.67, 15, 0),
        ('EMP-011', N'Obra La Molina', '2026-10-26', '06:15', '15:00', 8.75, 15, 0),
        ('EMP-011', N'Obra La Molina', '2026-10-27', '06:08', '15:00', 8.87, 8, 0),
        ('EMP-011', N'Obra La Molina', '2026-10-28', '05:50', '14:55', 9.08, 0, 0),
        ('EMP-011', N'Obra La Molina', '2026-10-29', NULL, NULL, 0, 0, 1),
        ('EMP-012', N'Obra La Molina', '2026-10-26', '05:55', '15:12', 9.28, 0, 0),
        ('EMP-012', N'Obra La Molina', '2026-10-27', '06:00', '14:55', 8.92, 0, 0),
        ('EMP-012', N'Obra La Molina', '2026-10-28', '06:25', '15:00', 8.58, 25, 0),
        ('EMP-012', N'Obra La Molina', '2026-10-29', '06:03', '15:00', 8.95, 3, 0)
     ) AS v (codigo, frente, fecha, ingreso, salida, horas, tardanza, falta)
JOIN empleados e ON e.codigo = v.codigo
JOIN frentes_obra f ON f.nombre = v.frente
CROSS JOIN usuarios u
WHERE u.nombre_usuario = N'admin';


-- 9. Usuario de la aplicación (mínimo privilegio, sin permisos de DDL)
-- La clave real NO se guarda en el repositorio: se define en el momento del despliegue.
CREATE USER app_asistencia WITH PASSWORD = '<CLAVE_SEGURA_AQUI>';
ALTER ROLE db_datareader ADD MEMBER app_asistencia;
ALTER ROLE db_datawriter ADD MEMBER app_asistencia;

-- 10. Verificación (evidencia para 2.2.3)
SELECT t.name AS tabla, SUM(p.rows) AS filas
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY t.name
ORDER BY t.name;

SELECT codigo, nombre, estado FROM empleados;

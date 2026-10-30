-- ============================================================================
-- bd_asistencia_nomina - esquema para PostgreSQL (Render o instalación local)
-- Ejecutar UNA sola vez, conectado a la base de datos del proyecto.
-- Ejemplo: psql "<cadena-de-conexion>" -f bd_asistencia_nomina_postgres.sql
-- ============================================================================

-- Protección: si el esquema ya existe, se detiene sin modificar nada.
DO $$
BEGIN
    IF to_regclass('public.roles') IS NOT NULL THEN
        RAISE EXCEPTION 'El esquema ya existe. Para recrearlo, elimine primero las tablas.';
    END IF;
END $$;

-- 1. roles
CREATE TABLE roles (
    id              INT           GENERATED ALWAYS AS IDENTITY,
    nombre          VARCHAR(30)   NOT NULL,
    descripcion     VARCHAR(150)  NULL,
    estado          BOOLEAN       NOT NULL DEFAULT TRUE,
    creado_el       TIMESTAMP(0)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_el  TIMESTAMP(0)  NULL,
    id_usuario      INT           NULL,
    CONSTRAINT pk_roles        PRIMARY KEY (id),
    CONSTRAINT uq_roles_nombre UNIQUE (nombre)
);

-- 2. usuarios
CREATE TABLE usuarios (
    id              INT           GENERATED ALWAYS AS IDENTITY,
    id_rol          INT           NOT NULL,
    nombre_usuario  VARCHAR(40)   NOT NULL,
    correo          VARCHAR(120)  NOT NULL,
    clave_hash      VARCHAR(255)  NOT NULL,
    estado          BOOLEAN       NOT NULL DEFAULT TRUE,
    creado_el       TIMESTAMP(0)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_el  TIMESTAMP(0)  NULL,
    id_usuario      INT           NULL,
    CONSTRAINT pk_usuarios                PRIMARY KEY (id),
    CONSTRAINT uq_usuarios_nombre_usuario UNIQUE (nombre_usuario),
    CONSTRAINT uq_usuarios_correo         UNIQUE (correo),
    CONSTRAINT fk_usuarios_rol            FOREIGN KEY (id_rol)     REFERENCES roles (id),
    CONSTRAINT fk_usuarios_usuario        FOREIGN KEY (id_usuario) REFERENCES usuarios (id)
);

-- Cierra la referencia circular roles -> usuarios
ALTER TABLE roles
    ADD CONSTRAINT fk_roles_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id);

-- 3. turnos
CREATE TABLE turnos (
    id              INT           GENERATED ALWAYS AS IDENTITY,
    nombre          VARCHAR(40)   NOT NULL,
    hora_inicio     TIME(0)       NOT NULL,
    hora_fin        TIME(0)       NOT NULL,
    estado          BOOLEAN       NOT NULL DEFAULT TRUE,
    creado_el       TIMESTAMP(0)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_el  TIMESTAMP(0)  NULL,
    id_usuario      INT           NOT NULL,
    CONSTRAINT pk_turnos        PRIMARY KEY (id),
    CONSTRAINT uq_turnos_nombre UNIQUE (nombre),
    CONSTRAINT ck_turnos_horas  CHECK (hora_fin > hora_inicio),
    CONSTRAINT fk_turnos_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id)
);

-- 4. frentes_obra
CREATE TABLE frentes_obra (
    id              INT           GENERATED ALWAYS AS IDENTITY,
    nombre          VARCHAR(80)   NOT NULL,
    distrito        VARCHAR(60)   NOT NULL,
    direccion       VARCHAR(150)  NULL,
    estado          BOOLEAN       NOT NULL DEFAULT TRUE,
    creado_el       TIMESTAMP(0)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_el  TIMESTAMP(0)  NULL,
    id_usuario      INT           NOT NULL,
    CONSTRAINT pk_frentes_obra         PRIMARY KEY (id),
    CONSTRAINT uq_frentes_obra_nombre  UNIQUE (nombre),
    CONSTRAINT fk_frentes_obra_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id)
);

-- 5. empleados (el código es el contenido del QR del fotocheck)
CREATE TABLE empleados (
    id              INT           GENERATED ALWAYS AS IDENTITY,
    id_turno        INT           NOT NULL,
    codigo          VARCHAR(10)   NOT NULL,
    nombre          VARCHAR(120)  NOT NULL,
    estado          BOOLEAN       NOT NULL DEFAULT TRUE,
    creado_el       TIMESTAMP(0)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_el  TIMESTAMP(0)  NULL,
    id_usuario      INT           NOT NULL,
    CONSTRAINT pk_empleados         PRIMARY KEY (id),
    CONSTRAINT uq_empleados_codigo  UNIQUE (codigo),
    CONSTRAINT fk_empleados_turno   FOREIGN KEY (id_turno)   REFERENCES turnos (id),
    CONSTRAINT fk_empleados_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id)
);

-- 6. registros_asistencia (un registro por empleado y por día)
CREATE TABLE registros_asistencia (
    id                INT           GENERATED ALWAYS AS IDENTITY,
    id_empleado       INT           NOT NULL,
    id_frente_obra    INT           NOT NULL,
    fecha_registro    DATE          NOT NULL,
    hora_ingreso      TIME(0)       NULL,
    hora_salida       TIME(0)       NULL,
    horas_trabajadas  NUMERIC(5,2)  NOT NULL DEFAULT 0,
    minutos_tardanza  INT           NOT NULL DEFAULT 0,
    es_falta          BOOLEAN       NOT NULL DEFAULT FALSE,
    estado            BOOLEAN       NOT NULL DEFAULT TRUE,
    creado_el         TIMESTAMP(0)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_el    TIMESTAMP(0)  NULL,
    id_usuario        INT           NOT NULL,
    CONSTRAINT pk_registros_asistencia PRIMARY KEY (id),
    CONSTRAINT uq_registros_asistencia_empleado_fecha UNIQUE (id_empleado, fecha_registro),
    CONSTRAINT fk_registros_asistencia_empleado    FOREIGN KEY (id_empleado)    REFERENCES empleados (id),
    CONSTRAINT fk_registros_asistencia_frente_obra FOREIGN KEY (id_frente_obra) REFERENCES frentes_obra (id),
    CONSTRAINT fk_registros_asistencia_usuario     FOREIGN KEY (id_usuario)     REFERENCES usuarios (id),
    CONSTRAINT ck_registros_asistencia_horas    CHECK (horas_trabajadas BETWEEN 0 AND 24),
    CONSTRAINT ck_registros_asistencia_tardanza CHECK (minutos_tardanza >= 0),
    CONSTRAINT ck_registros_asistencia_salida   CHECK (hora_salida IS NULL OR hora_ingreso IS NOT NULL),
    CONSTRAINT ck_registros_asistencia_falta    CHECK (es_falta = FALSE OR hora_ingreso IS NULL)
);

-- 7. Índices
CREATE INDEX idx_usuarios_rol                     ON usuarios (id_rol);
CREATE INDEX idx_empleados_turno                  ON empleados (id_turno);
CREATE INDEX idx_registros_asistencia_frente_obra ON registros_asistencia (id_frente_obra);
CREATE INDEX idx_registros_asistencia_fecha       ON registros_asistencia (fecha_registro);

-- 8. Datos iniciales (catálogos, usuarios de ejemplo, empleados y asistencia de ejemplo)
-- Los hashes de usuarios son marcadores: se reemplazan cuando la aplicación tenga inicio de sesión.
INSERT INTO roles (nombre, descripcion) VALUES
    ('ADMINISTRADOR',      'Administración general del sistema'),
    ('RRHH',               'Consulta y corrección de asistencia'),
    ('SUPERVISOR',         'Consulta de asistencia por frente de obra'),
    ('CONTROL_ASISTENCIA', 'Cuenta técnica de la tablet de registro de asistencia');

INSERT INTO usuarios (id_rol, nombre_usuario, correo, clave_hash)
SELECT id, 'admin', 'admin@construandina.example', '$2a$10$REEMPLAZAR_CON_HASH_BCRYPT'
FROM roles WHERE nombre = 'ADMINISTRADOR';

INSERT INTO usuarios (id_rol, nombre_usuario, correo, clave_hash)
SELECT id, 'tablet_asistencia', 'tablet@construandina.example', '$2a$10$REEMPLAZAR_CON_HASH_BCRYPT'
FROM roles WHERE nombre = 'CONTROL_ASISTENCIA';

INSERT INTO turnos (nombre, hora_inicio, hora_fin, id_usuario)
SELECT v.nombre, v.inicio::time, v.fin::time, u.id
FROM (VALUES
        ('Turno diurno',   '07:00', '16:00'),
        ('Turno temprano', '06:00', '15:00')
     ) AS v (nombre, inicio, fin)
CROSS JOIN usuarios u
WHERE u.nombre_usuario = 'admin';

INSERT INTO frentes_obra (nombre, distrito, id_usuario)
SELECT v.nombre, v.distrito, u.id
FROM (VALUES
        ('Obra San Isidro', 'San Isidro'),
        ('Obra Surco',      'Santiago de Surco'),
        ('Obra La Molina',  'La Molina')
     ) AS v (nombre, distrito)
CROSS JOIN usuarios u
WHERE u.nombre_usuario = 'admin';

INSERT INTO empleados (codigo, nombre, id_turno, id_usuario)
SELECT v.codigo, v.nombre, t.id, u.id
FROM (VALUES
        ('EMP-001', 'Juan Ramírez Soto', 'Turno diurno'),
        ('EMP-002', 'María Castro Díaz', 'Turno diurno'),
        ('EMP-003', 'Luis Huamán Quispe', 'Turno diurno'),
        ('EMP-004', 'Rosa Quispe Mamani', 'Turno diurno'),
        ('EMP-005', 'Carlos Flores Ticona', 'Turno diurno'),
        ('EMP-006', 'Ana Lucía Torres Vega', 'Turno diurno'),
        ('EMP-007', 'Pedro Salas Ríos', 'Turno temprano'),
        ('EMP-008', 'Jorge Ccama Pérez', 'Turno temprano'),
        ('EMP-009', 'Lucía Mendoza Ruiz', 'Turno temprano'),
        ('EMP-010', 'Miguel Ángel Ortiz Paredes', 'Turno temprano'),
        ('EMP-011', 'Elena Gutiérrez Vilca', 'Turno temprano'),
        ('EMP-012', 'Daniel Sánchez Mora', 'Turno temprano')
     ) AS v (codigo, nombre, turno)
JOIN turnos t ON t.nombre = v.turno
CROSS JOIN usuarios u
WHERE u.nombre_usuario = 'admin';

-- Asistencia de ejemplo: 26 al 29 de octubre de 2026 (una fila por empleado y día).
-- Las horas y tardanzas siguen las reglas de la aplicación.
INSERT INTO registros_asistencia (id_empleado, id_frente_obra, fecha_registro, hora_ingreso, hora_salida,
                                  horas_trabajadas, minutos_tardanza, es_falta, id_usuario)
SELECT e.id, f.id, v.fecha, v.ingreso, v.salida, v.horas, v.tardanza, v.falta, u.id
FROM (VALUES
        ('EMP-001', 'Obra San Isidro', '2026-10-26'::date, '07:25'::time, '16:30'::time, 9.08::numeric, 25, FALSE),
        ('EMP-001', 'Obra San Isidro', '2026-10-27'::date, '06:55'::time, '16:00'::time, 9.08::numeric, 0, FALSE),
        ('EMP-001', 'Obra San Isidro', '2026-10-28'::date, '07:25'::time, '16:05'::time, 8.67::numeric, 25, FALSE),
        ('EMP-001', 'Obra San Isidro', '2026-10-29'::date, '07:25'::time, '16:30'::time, 9.08::numeric, 25, FALSE),
        ('EMP-002', 'Obra Surco', '2026-10-26'::date, '07:15'::time, '16:00'::time, 8.75::numeric, 15, FALSE),
        ('EMP-002', 'Obra Surco', '2026-10-27'::date, NULL::time, NULL::time, 0::numeric, 0, TRUE),
        ('EMP-002', 'Obra Surco', '2026-10-28'::date, '07:00'::time, '15:55'::time, 8.92::numeric, 0, FALSE),
        ('EMP-002', 'Obra Surco', '2026-10-29'::date, '07:15'::time, '16:30'::time, 9.25::numeric, 15, FALSE),
        ('EMP-003', 'Obra Surco', '2026-10-26'::date, '07:00'::time, '16:00'::time, 9.00::numeric, 0, FALSE),
        ('EMP-003', 'Obra Surco', '2026-10-27'::date, '07:03'::time, '16:05'::time, 9.03::numeric, 3, FALSE),
        ('EMP-003', 'Obra Surco', '2026-10-28'::date, '07:25'::time, '16:30'::time, 9.08::numeric, 25, FALSE),
        ('EMP-003', 'Obra Surco', '2026-10-29'::date, '07:03'::time, '15:55'::time, 8.87::numeric, 3, FALSE),
        ('EMP-004', 'Obra La Molina', '2026-10-26'::date, '07:00'::time, '16:05'::time, 9.08::numeric, 0, FALSE),
        ('EMP-004', 'Obra La Molina', '2026-10-27'::date, '07:00'::time, '15:55'::time, 8.92::numeric, 0, FALSE),
        ('EMP-004', 'Obra La Molina', '2026-10-28'::date, '07:03'::time, '16:00'::time, 8.95::numeric, 3, FALSE),
        ('EMP-004', 'Obra La Molina', '2026-10-29'::date, '06:55'::time, '16:05'::time, 9.17::numeric, 0, FALSE),
        ('EMP-005', 'Obra La Molina', '2026-10-26'::date, '06:55'::time, '16:05'::time, 9.17::numeric, 0, FALSE),
        ('EMP-005', 'Obra La Molina', '2026-10-27'::date, '07:15'::time, '16:05'::time, 8.83::numeric, 15, FALSE),
        ('EMP-005', 'Obra La Molina', '2026-10-28'::date, '07:00'::time, '16:05'::time, 9.08::numeric, 0, FALSE),
        ('EMP-005', 'Obra La Molina', '2026-10-29'::date, '07:15'::time, '16:12'::time, 8.95::numeric, 15, FALSE),
        ('EMP-006', 'Obra La Molina', '2026-10-26'::date, '07:00'::time, '16:00'::time, 9.00::numeric, 0, FALSE),
        ('EMP-006', 'Obra La Molina', '2026-10-27'::date, '07:25'::time, '16:30'::time, 9.08::numeric, 25, FALSE),
        ('EMP-006', 'Obra La Molina', '2026-10-28'::date, '07:08'::time, '16:05'::time, 8.95::numeric, 8, FALSE),
        ('EMP-006', 'Obra La Molina', '2026-10-29'::date, '07:00'::time, '15:55'::time, 8.92::numeric, 0, FALSE),
        ('EMP-007', 'Obra La Molina', '2026-10-26'::date, '06:15'::time, '15:30'::time, 9.25::numeric, 15, FALSE),
        ('EMP-007', 'Obra La Molina', '2026-10-27'::date, '06:25'::time, '15:00'::time, 8.58::numeric, 25, FALSE),
        ('EMP-007', 'Obra La Molina', '2026-10-28'::date, '06:00'::time, '15:12'::time, 9.20::numeric, 0, FALSE),
        ('EMP-007', 'Obra La Molina', '2026-10-29'::date, '06:25'::time, '15:30'::time, 9.08::numeric, 25, FALSE),
        ('EMP-008', 'Obra Surco', '2026-10-26'::date, '06:08'::time, '15:05'::time, 8.95::numeric, 8, FALSE),
        ('EMP-008', 'Obra Surco', '2026-10-27'::date, '06:00'::time, '14:55'::time, 8.92::numeric, 0, FALSE),
        ('EMP-008', 'Obra Surco', '2026-10-28'::date, NULL::time, NULL::time, 0::numeric, 0, TRUE),
        ('EMP-008', 'Obra Surco', '2026-10-29'::date, '06:15'::time, '15:12'::time, 8.95::numeric, 15, FALSE),
        ('EMP-009', 'Obra Surco', '2026-10-26'::date, '06:00'::time, '15:00'::time, 9.00::numeric, 0, FALSE),
        ('EMP-009', 'Obra Surco', '2026-10-27'::date, '06:15'::time, '15:12'::time, 8.95::numeric, 15, FALSE),
        ('EMP-009', 'Obra Surco', '2026-10-28'::date, '06:15'::time, '15:05'::time, 8.83::numeric, 15, FALSE),
        ('EMP-009', 'Obra Surco', '2026-10-29'::date, '05:50'::time, '15:00'::time, 9.17::numeric, 0, FALSE),
        ('EMP-010', 'Obra Surco', '2026-10-26'::date, '05:55'::time, '15:05'::time, 9.17::numeric, 0, FALSE),
        ('EMP-010', 'Obra Surco', '2026-10-27'::date, '06:25'::time, '15:00'::time, 8.58::numeric, 25, FALSE),
        ('EMP-010', 'Obra Surco', '2026-10-28'::date, '06:00'::time, '15:05'::time, 9.08::numeric, 0, FALSE),
        ('EMP-010', 'Obra Surco', '2026-10-29'::date, '06:15'::time, '14:55'::time, 8.67::numeric, 15, FALSE),
        ('EMP-011', 'Obra La Molina', '2026-10-26'::date, '06:15'::time, '15:00'::time, 8.75::numeric, 15, FALSE),
        ('EMP-011', 'Obra La Molina', '2026-10-27'::date, '06:08'::time, '15:00'::time, 8.87::numeric, 8, FALSE),
        ('EMP-011', 'Obra La Molina', '2026-10-28'::date, '05:50'::time, '14:55'::time, 9.08::numeric, 0, FALSE),
        ('EMP-011', 'Obra La Molina', '2026-10-29'::date, NULL::time, NULL::time, 0::numeric, 0, TRUE),
        ('EMP-012', 'Obra La Molina', '2026-10-26'::date, '05:55'::time, '15:12'::time, 9.28::numeric, 0, FALSE),
        ('EMP-012', 'Obra La Molina', '2026-10-27'::date, '06:00'::time, '14:55'::time, 8.92::numeric, 0, FALSE),
        ('EMP-012', 'Obra La Molina', '2026-10-28'::date, '06:25'::time, '15:00'::time, 8.58::numeric, 25, FALSE),
        ('EMP-012', 'Obra La Molina', '2026-10-29'::date, '06:03'::time, '15:00'::time, 8.95::numeric, 3, FALSE)
     ) AS v (codigo, frente, fecha, ingreso, salida, horas, tardanza, falta)
JOIN empleados e ON e.codigo = v.codigo
JOIN frentes_obra f ON f.nombre = v.frente
CROSS JOIN usuarios u
WHERE u.nombre_usuario = 'admin';

-- 9. Usuario de la aplicación (OPCIONAL).
-- En Render la aplicación usa el usuario que te da el servicio, así que este bloque no es necesario.
-- Solo si tu servidor PostgreSQL permite crear roles (instalación local), quita los guiones y pon tu clave:
-- CREATE ROLE app_asistencia LOGIN PASSWORD '<CLAVE_SEGURA_AQUI>';
-- GRANT USAGE ON SCHEMA public TO app_asistencia;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_asistencia;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_asistencia;

-- 10. Verificación
SELECT 'roles' AS tabla, COUNT(*) AS filas FROM roles
UNION ALL SELECT 'usuarios', COUNT(*) FROM usuarios
UNION ALL SELECT 'turnos', COUNT(*) FROM turnos
UNION ALL SELECT 'frentes_obra', COUNT(*) FROM frentes_obra
UNION ALL SELECT 'empleados', COUNT(*) FROM empleados
UNION ALL SELECT 'registros_asistencia', COUNT(*) FROM registros_asistencia;

SELECT codigo, nombre, estado FROM empleados ORDER BY codigo;

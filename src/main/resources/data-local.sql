-- Datos de ejemplo para el perfil local (mismos que el script db/bd_asistencia_nomina_ddl.sql).
INSERT INTO turnos (nombre, hora_inicio, hora_fin, id_usuario, estado)
VALUES ('Turno diurno', '07:00:00', '16:00:00', 1, TRUE);

INSERT INTO frentes_obra (nombre, distrito, id_usuario, estado) VALUES
    ('Obra San Isidro', 'San Isidro', 1, TRUE),
    ('Obra Surco', 'Santiago de Surco', 1, TRUE),
    ('Obra La Molina', 'La Molina', 1, TRUE);

INSERT INTO empleados (id_turno, codigo, nombre, id_usuario, estado) VALUES
    (1, 'EMP-001', 'Juan Ramírez Soto', 1, TRUE),
    (1, 'EMP-002', 'María Castro Díaz', 1, TRUE),
    (1, 'EMP-003', 'Luis Huamán Quispe', 1, TRUE);

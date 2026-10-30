# Sistema de Control de Asistencia

Sistema web/API para el control de asistencia de Corporación ConstruAndina S.A.C.
Permite registrar la entrada y la salida de cada trabajador desde la tablet de su frente de obra
(con código de empleado o QR del fotocheck), calcula horas trabajadas y tardanzas según el turno,
registra faltas al cierre del día y genera reportes por frente de obra y periodo.

Tecnologías: Java 21, Spring Boot 3.3.5, Spring Data JPA, Maven, Azure SQL Database (SQL Server).

## Estructura

```
sistema-control-asistencia/
├── pom.xml
├── db/bd_asistencia_nomina_ddl.sql          script de creación del esquema (SQL Server)
├── src/main/java/com/construandina/asistencia/
│   ├── SistemaAsistenciaApplication.java
│   ├── model/        Auditable, Empleado, Turno, FrenteObra, RegistroAsistencia
│   ├── repository/   interfaces Spring Data JPA
│   ├── service/      AsistenciaService (reglas de negocio)
│   ├── controller/   AsistenciaController, HealthController
│   ├── dto/          MarcajeRequest, RegistroResponse
│   └── exception/    NegocioException, GlobalExceptionHandler
├── src/main/resources/application.properties   configuración (Azure SQL)
└── src/test/                                   pruebas con H2 en modo SQL Server
```

## Endpoints

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/` | Vista web para la tablet: entrada, cierre y reporte |
| POST | `/api/asistencia/entrada` | Entrada del empleado. Cuerpo: `{"codigo": "EMP-001", "idFrenteObra": 1}` |
| POST | `/api/asistencia/salida` | Cierre (salida) del empleado. Cuerpo: `{"codigo": "EMP-001"}` |
| POST | `/api/asistencia/marcajes` | Marcaje automático: entrada si aún no tiene, si no salida |
| GET | `/api/frentes` | Frentes de obra activos (local de registro) |
| GET | `/api/asistencia/reporte?idFrente=1&inicio=2026-10-01&fin=2026-10-31` | Reporte de asistencia de un frente |
| POST | `/api/asistencia/cierre?idFrente=1&fecha=2026-10-30` | Registra faltas de los empleados sin marcaje ese día |
| GET | `/api/health` | Estado de la aplicación |
| GET | `/api/health/db` | Prueba de conexión con la base de datos |

## Reglas de negocio

1. El código debe existir (`404`) y el empleado debe estar activo (`422`).
2. El primer marcaje del día registra la entrada y calcula la tardanza: minutos desde la hora de inicio del turno.
3. El segundo marcaje registra la salida y calcula las horas trabajadas con dos decimales.
4. Un tercer marcaje el mismo día se rechaza (`409`).
5. El cierre del día marca como falta a los empleados activos sin ningún marcaje en la fecha.

Limitación conocida: el sistema todavía no asigna un frente de obra a cada empleado, así que la falta
se registra en el frente indicado en el cierre.

## Ejecución local (sin Azure)

Requisito: JDK 21 o superior. No hace falta instalar Maven: el proyecto incluye el Maven Wrapper (`mvnw`).

El perfil `local` usa H2 en memoria y carga datos de ejemplo (`src/main/resources/data-local.sql`):
los empleados `EMP-001`, `EMP-002` y `EMP-003` y los frentes de obra 1, 2 y 3.

```powershell
# Windows (PowerShell)
$env:SPRING_PROFILES_ACTIVE="local"; .\mvnw.cmd spring-boot:run
```

```bash
# Linux / macOS / Git Bash
SPRING_PROFILES_ACTIVE=local ./mvnw spring-boot:run
```

En VS Code: pestaña *Run and Debug*, configuración **Local (H2 en memoria)**.
La consola de H2 queda en `http://localhost:8080/h2-console` (JDBC URL `jdbc:h2:mem:asistencia`, usuario `sa`).

Pruebas automatizadas (también con H2, `src/test/resources/application.properties`):

```bash
./mvnw test
```

## Ejecución contra Azure SQL Database

1. Ejecutar `db/bd_asistencia_nomina_ddl.sql` en la base `bd_asistencia_nomina`, con el usuario administrador.
2. Reemplazar los hashes de ejemplo y la clave del usuario `app_asistencia` en el script.
3. Definir las variables de entorno (nunca escribirlas en el código):

```bash
export DB_SERVIDOR=<nombre-del-servidor>
export DB_USUARIO=app_asistencia
export DB_CLAVE=<clave>
export APP_USUARIO_AUDITORIA_ID=1
./mvnw spring-boot:run
```

En VS Code: copiar `.env.example` a `.env`, completar los valores y usar la configuración **Azure SQL (usa .env)**.

Con `spring.jpa.hibernate.ddl-auto=validate`, la aplicación no modifica el esquema: si una columna
no coincide con el script, el arranque falla y lo indica.

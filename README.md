# Sistema de Control de Asistencia

Sistema web/API para el control de asistencia de Corporación ConstruAndina S.A.C.
Registra la entrada y la salida de cada trabajador desde la tablet de su frente de obra
(código de empleado o QR del fotocheck), calcula horas trabajadas y tardanzas según el turno,
registra faltas al cierre del día y genera reportes por frente de obra y periodo.

Tecnologías: Java 21, Spring Boot 3.3.5, Spring Data JPA, Maven, PostgreSQL.

## Estructura

```
├── pom.xml
├── Dockerfile                             imagen para desplegar (Render u otro servicio con Docker)
├── db/bd_asistencia_nomina_postgres.sql   script de creación del esquema y datos de ejemplo (PostgreSQL)
├── src/main/java/com/construandina/asistencia/
│   ├── model/        Auditable, Empleado, Turno, FrenteObra, RegistroAsistencia
│   ├── repository/   interfaces Spring Data JPA
│   ├── service/      AsistenciaService (reglas de negocio)
│   ├── controller/   AsistenciaController, FrenteObraController, HealthController, InicioController
│   ├── dto/          MarcajeRequest, SalidaRequest, RegistroResponse, FrenteObraResponse
│   └── exception/    NegocioException, GlobalExceptionHandler
└── src/test/                              pruebas con H2 en modo PostgreSQL (no necesitan base real)
```

## Endpoints

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api` | Índice de la API |
| GET | `/api/frentes` | Frentes de obra activos |
| POST | `/api/asistencia/entrada` | Entrada: `{"codigo": "EMP-001", "idFrenteObra": 1}` |
| POST | `/api/asistencia/salida` | Salida: `{"codigo": "EMP-001"}` |
| POST | `/api/asistencia/marcajes` | Automático: entrada si no tiene, si no salida |
| GET | `/api/asistencia/reporte?idFrente=1&inicio=2026-10-26&fin=2026-10-29` | Reporte de un frente |
| POST | `/api/asistencia/cierre?idFrente=1&fecha=2026-10-30` | Registra faltas del día |
| GET | `/api/health` | Estado de la aplicación |
| GET | `/api/health/db` | Conexión con la base de datos |

## Reglas de negocio

1. El código debe existir (404) y el empleado debe estar activo (422).
2. La primera entrada del día registra la hora y calcula la tardanza frente al inicio del turno.
3. La salida calcula las horas trabajadas con dos decimales. Debe ser posterior a la entrada.
4. Una segunda entrada o una segunda salida el mismo día se rechazan (409).
5. El cierre marca como falta a los empleados activos sin ningún marcaje en la fecha.

Limitación conocida: el sistema todavía no asigna un frente a cada empleado, así que la falta se registra en el frente indicado en el cierre.

## Pruebas (sin base de datos real)

```
./mvnw test          (Windows: mvnw.cmd test)
```

## Ejecución local con PostgreSQL

1. Crea una base vacía `bd_asistencia_nomina` en tu PostgreSQL local.
2. Ejecuta el script: `psql -h localhost -U postgres -d bd_asistencia_nomina -f db/bd_asistencia_nomina_postgres.sql`
3. Copia `.env.example` a `.env` y completa `DB_CLAVE`. Luego, en PowerShell:

```
$env:DB_URL = "jdbc:postgresql://localhost:5432/bd_asistencia_nomina"
$env:DB_USUARIO = "postgres"
$env:DB_CLAVE = "tu-clave"
.\mvnw.cmd spring-boot:run
```

Comprueba `http://localhost:8080/api/health/db`: debe responder `"base":"conectada"`.

## Despliegue en Render

1. **Base de datos:** en Render, crea un servicio **PostgreSQL** (plan gratuito). Revisa en Render los límites del plan gratuito, porque pueden cambiar. Copia los datos de conexión externos (host, base, usuario y clave).
2. **Esquema:** ejecuta el script con esa conexión, por ejemplo:
   `psql "postgresql://USUARIO:CLAVE@HOST/BASE?sslmode=require" -f db/bd_asistencia_nomina_postgres.sql`
3. **Servicio web:** crea un **Web Service** conectado a este repositorio de GitHub, con entorno **Docker**.
4. **Variables de entorno** en el servicio web:
   - `DB_URL` = `jdbc:postgresql://HOST/BASE?sslmode=require`
   - `DB_USUARIO` = el usuario de la base
   - `DB_CLAVE` = la clave de la base
   - `APP_USUARIO_AUDITORIA_ID` = `1`
5. Al terminar el despliegue, comprueba `https://TU-SERVICIO.onrender.com/api/health/db`.

El plan gratuito de Render duerme el servicio tras un tiempo sin uso; la primera petición puede tardar.

# Ejecutar contra SQL Server local (Docker)

1. Docker Desktop abierto y el contenedor `sqlserver` activo (`docker start sqlserver`).
2. La base `bd_asistencia_nomina` ya creada y el script ya ejecutado.
3. En PowerShell, dentro de la carpeta del proyecto:

```
$env:SPRING_PROFILES_ACTIVE = "sqlserver"
$env:DB_CLAVE = "<CLAVE_SEGURA_AQUI>"
.\mvnw.cmd spring-boot:run
```

4. Comprobar en el navegador: http://localhost:8080/api/health/db debe responder `"base": "conectada"`.

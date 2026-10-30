package com.construandina.asistencia.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

/** Índice de la API: indica que el servicio está activo y lista los endpoints disponibles. */
@RestController
public class InicioController {

    @GetMapping("/api")
    public Map<String, Object> inicio() {
        Map<String, String> endpoints = new LinkedHashMap<>();
        endpoints.put("POST /api/asistencia/entrada", "Entrada del empleado. Cuerpo: {\"codigo\": \"EMP-001\", \"idFrenteObra\": 1}");
        endpoints.put("POST /api/asistencia/salida", "Cierre (salida) del empleado. Cuerpo: {\"codigo\": \"EMP-001\"}");
        endpoints.put("POST /api/asistencia/marcajes", "Marcaje automático: entrada si no tiene, si no salida");
        endpoints.put("GET /api/frentes", "Locales de registro (frentes de obra activos)");
        endpoints.put("GET /api/asistencia/reporte?idFrente=1&inicio=2026-10-01&fin=2026-10-31", "Reporte de asistencia de un frente");
        endpoints.put("POST /api/asistencia/cierre?idFrente=1&fecha=2026-10-30", "Registra faltas del día");
        endpoints.put("GET /api/health", "Estado de la aplicación");
        endpoints.put("GET /api/health/db", "Conexión con la base de datos");

        Map<String, Object> respuesta = new LinkedHashMap<>();
        respuesta.put("aplicacion", "Sistema de Control de Asistencia - ConstruAndina");
        respuesta.put("estado", "UP");
        respuesta.put("endpoints", endpoints);
        return respuesta;
    }
}

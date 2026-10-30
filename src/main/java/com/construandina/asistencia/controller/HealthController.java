package com.construandina.asistencia.controller;

import com.construandina.asistencia.repository.EmpleadoRepository;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class HealthController {

    private final EmpleadoRepository empleados;

    public HealthController(EmpleadoRepository empleados) {
        this.empleados = empleados;
    }

    @GetMapping("/api/health")
    public Map<String, String> salud() {
        return Map.of("estado", "UP");
    }

    /** Verifica la conexión con Azure SQL Database. */
    @GetMapping("/api/health/db")
    public ResponseEntity<Map<String, String>> saludDb() {
        try {
            empleados.count();
            return ResponseEntity.ok(Map.of("estado", "UP", "base", "conectada"));
        } catch (DataAccessException ex) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                    .body(Map.of("estado", "DOWN", "base", "sin conexión"));
        }
    }
}

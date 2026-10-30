package com.construandina.asistencia.controller;

import com.construandina.asistencia.dto.MarcajeRequest;
import com.construandina.asistencia.dto.RegistroResponse;
import com.construandina.asistencia.dto.SalidaRequest;
import com.construandina.asistencia.service.AsistenciaService;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/asistencia")
public class AsistenciaController {

    private final AsistenciaService servicio;

    public AsistenciaController(AsistenciaService servicio) {
        this.servicio = servicio;
    }

    /** Marcaje desde la tablet: código o QR del empleado y frente de obra. */
    @PostMapping("/marcajes")
    public RegistroResponse marcar(@Valid @RequestBody MarcajeRequest solicitud) {
        var registro = servicio.registrarMarcaje(
                solicitud.codigo(), solicitud.idFrenteObra(), LocalDateTime.now());
        return RegistroResponse.desde(registro);
    }

    /** Entrada del empleado en el frente de obra de la tablet. */
    @PostMapping("/entrada")
    public RegistroResponse entrada(@Valid @RequestBody MarcajeRequest solicitud) {
        var registro = servicio.registrarEntrada(
                solicitud.codigo(), solicitud.idFrenteObra(), LocalDateTime.now());
        return RegistroResponse.desde(registro);
    }

    /** Cierre del empleado: registra su salida del día. */
    @PostMapping("/salida")
    public RegistroResponse salida(@Valid @RequestBody SalidaRequest solicitud) {
        return RegistroResponse.desde(servicio.registrarSalida(solicitud.codigo(), LocalDateTime.now()));
    }

    /** Reporte de asistencia de un frente de obra en un rango de fechas. */
    @GetMapping("/reporte")
    public List<RegistroResponse> reporte(
            @RequestParam Integer idFrente,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate inicio,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fin) {
        return servicio.generarReporte(idFrente, inicio, fin).stream()
                .map(RegistroResponse::desde)
                .toList();
    }

    /** Cierre del día: registra como faltas a los empleados sin marcaje. */
    @PostMapping("/cierre")
    public Map<String, Integer> cierre(
            @RequestParam Integer idFrente,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fecha) {
        return Map.of("faltasRegistradas", servicio.marcarFaltas(fecha, idFrente));
    }
}

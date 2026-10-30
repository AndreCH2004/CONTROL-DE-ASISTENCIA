package com.construandina.asistencia.dto;

import com.construandina.asistencia.model.RegistroAsistencia;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;

public record RegistroResponse(
        Integer id,
        String codigoEmpleado,
        String nombreEmpleado,
        String frenteObra,
        LocalDate fecha,
        LocalTime horaIngreso,
        LocalTime horaSalida,
        BigDecimal horasTrabajadas,
        int minutosTardanza,
        boolean esFalta) {

    public static RegistroResponse desde(RegistroAsistencia r) {
        return new RegistroResponse(
                r.getId(),
                r.getEmpleado().getCodigo(),
                r.getEmpleado().getNombre(),
                r.getFrenteObra().getNombre(),
                r.getFechaRegistro(),
                r.getHoraIngreso(),
                r.getHoraSalida(),
                r.getHorasTrabajadas(),
                r.getMinutosTardanza(),
                r.isEsFalta());
    }
}

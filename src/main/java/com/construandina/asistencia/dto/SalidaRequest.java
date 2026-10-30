package com.construandina.asistencia.dto;

import jakarta.validation.constraints.NotBlank;

/** Cierre del empleado: basta el código, porque la salida se registra sobre la entrada del día. */
public record SalidaRequest(@NotBlank String codigo) {
}

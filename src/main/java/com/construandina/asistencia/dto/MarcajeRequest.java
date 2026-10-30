package com.construandina.asistencia.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record MarcajeRequest(
        @NotBlank String codigo,
        @NotNull Integer idFrenteObra) {
}

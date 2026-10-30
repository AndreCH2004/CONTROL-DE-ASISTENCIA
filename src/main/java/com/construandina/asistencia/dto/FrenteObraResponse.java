package com.construandina.asistencia.dto;

import com.construandina.asistencia.model.FrenteObra;

public record FrenteObraResponse(Integer id, String nombre, String distrito) {

    public static FrenteObraResponse desde(FrenteObra f) {
        return new FrenteObraResponse(f.getId(), f.getNombre(), f.getDistrito());
    }
}

package com.construandina.asistencia.controller;

import com.construandina.asistencia.dto.FrenteObraResponse;
import com.construandina.asistencia.repository.FrenteObraRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/frentes")
public class FrenteObraController {

    private final FrenteObraRepository frentes;

    public FrenteObraController(FrenteObraRepository frentes) {
        this.frentes = frentes;
    }

    /** Frentes de obra activos, para elegir el frente en la tablet. */
    @GetMapping
    public List<FrenteObraResponse> listar() {
        return frentes.findByEstadoTrueOrderByNombreAsc().stream()
                .map(FrenteObraResponse::desde)
                .toList();
    }
}
